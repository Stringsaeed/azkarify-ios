import Combine
import Foundation

/// The errors that can be presented by the location picker.
///
/// The store keeps the existing string properties for the SwiftUI views and
/// also exposes typed failures for callers that need to distinguish an
/// unavailable service from App Attest being unusable on a simulator.
enum LocationCatalogError: LocalizedError, Equatable, Sendable {
  case unavailable
  case unsupportedSimulator
  case invalidCountryCode
  case invalidQuery
  case invalidPayload
  case invalidHTTPResponse
  case missingCacheForNotModifiedResponse
  case responseTooLarge
  case datasetChanged
  case httpStatus(Int)

  var errorDescription: String? {
    switch self {
    case .unavailable:
      return "The location catalog is unavailable."
    case .unsupportedSimulator:
      return "Location search is unavailable on this simulator."
    case .invalidCountryCode:
      return "The country code is invalid."
    case .invalidQuery:
      return "Enter at least two characters and no more than five words."
    case .invalidPayload:
      return "The location catalog response is invalid."
    case .invalidHTTPResponse:
      return "The location catalog response was invalid."
    case .missingCacheForNotModifiedResponse:
      return "The location catalog cache is missing."
    case .responseTooLarge:
      return "The location catalog response is too large."
    case .datasetChanged:
      return "The location catalog changed while it was loading."
    case .httpStatus(let status):
      return "The location catalog request failed (HTTP \(status))."
    }
  }
}

/// Loads the authenticated Countries API while preserving bundled location
/// presets when the network is unavailable.
///
/// `CountriesAPITransport` is the only network boundary used here. The app
/// supplies its App Attest implementation and tests inject a fake transport.
/// URLSession is intentionally absent from this type, so a catalog request
/// cannot silently bypass request attestation.
@MainActor
final class LocationCatalogStore: ObservableObject {
  static let cacheTimeToLive: TimeInterval = 24 * 60 * 60
  static let maximumResponseBytes = 10 * 1024 * 1024
  static let countryPageSize = 250
  static let cityPageSize = 100

  @Published private(set) var countries: [PrayerCountry]
  @Published private(set) var countriesLoading = false
  @Published private(set) var loadingCountryCodes: Set<String> = []
  @Published private(set) var countriesError: String?
  @Published private(set) var cityErrors: [String: String] = [:]
  @Published private(set) var countriesFailure: LocationCatalogError?
  @Published private(set) var cityFailures: [String: LocationCatalogError] = [:]

  private let baseURL: URL?
  private let cacheDirectory: URL
  private let transport: CountriesAPITransport?
  private let now: () -> Date
  private let fileManager: FileManager

  private var citiesByQuery: [CityQueryKey: [PrayerCity]] = [:]
  private var cityNextCursors: [CityQueryKey: String] = [:]
  private var cityDatasetVersions: [CityQueryKey: String] = [:]
  private var cityPageETags: [CityPageKey: String] = [:]
  private var cityPageFetchedAt: [CityPageKey: Date] = [:]
  private var cityTasks: [CityQueryKey: Task<Void, Never>] = [:]
  private var countryTasks: [String: Task<Void, Never>] = [:]
  private var latestCityErrorKeys: [String: String] = [:]
  private var preferredLanguage = "en"

  init(
    baseURL: URL? = LocationCatalogStore.configuredBaseURL(),
    cacheDirectory: URL = LocationCatalogStore.defaultCacheDirectory(),
    transport: CountriesAPITransport? = nil,
    now: @escaping () -> Date = Date.init,
    fileManager: FileManager = .default
  ) {
    let normalizedBaseURL = Self.normalizedBaseURL(baseURL)
    self.baseURL = normalizedBaseURL
    self.cacheDirectory = cacheDirectory.appendingPathComponent(
      Self.cacheNamespace(for: normalizedBaseURL), isDirectory: true)
    if let transport {
      self.transport = transport
    } else if let normalizedBaseURL {
      let environment = Bundle.main.object(forInfoDictionaryKey: "AppAttestEnvironment") as? String
      self.transport = try? CountriesAPIClient(
        baseURL: normalizedBaseURL,
        environment: environment)
    } else {
      self.transport = nil
    }
    self.now = now
    self.fileManager = fileManager

    self.countries = PrayerCountryCatalog.countries

    // Hydrate only a complete, coherent cached chain. Publishing the first
    // page of a paginated world list as if it were the full list would hide
    // countries when the app is offline between page requests.
    let language = Self.normalizedLanguage(Bundle.main.preferredLocalizations.first ?? "en")
    if let cached = readCountrySnapshot(language: language)
      ?? readCountrySnapshot(language: language == "en" ? "ar" : "en")
      ?? readCompleteCountryCache(language: language)
    {
      self.countries = cached
    }
  }

  /// Returns a loaded server result for a country/query. Empty query is the
  /// initial popular page; search results remain separate from that page.
  func cities(
    for countryCode: String,
    query: String = "",
    language: String = "en"
  ) -> [PrayerCity] {
    let normalizedCode = countryCode.uppercased()
    let normalizedLanguage = Self.normalizedLanguage(language)
    let normalizedQuery = Self.normalizedQuery(query) ?? ""
    let key = CityQueryKey(
      countryCode: normalizedCode,
      query: normalizedQuery,
      language: normalizedLanguage)

    if citiesByQuery[key] == nil,
      let cached = readCityPage(
        countryCode: normalizedCode,
        query: normalizedQuery,
        language: normalizedLanguage,
        cursor: nil)
    {
      citiesByQuery[key] = cached.items
      if let nextCursor = cached.nextCursor { cityNextCursors[key] = nextCursor }
      cityDatasetVersions[key] = cached.datasetVersion
      if let etag = cached.etag {
        cityPageETags[CityPageKey(queryKey: key, cursor: nil)] = etag
      }
      cityPageFetchedAt[CityPageKey(queryKey: key, cursor: nil)] = cached.fetchedAt
    }

    if let result = citiesByQuery[key] { return result }

    // Bundled search is deliberately limited to the selected country. It gives
    // a denied/offline user a useful setup path without pretending the local
    // preset list is a complete world city database.
    let bundled = PrayerCity.cities(for: normalizedCode)
    guard !normalizedQuery.isEmpty else { return bundled }
    return Self.filterCities(bundled, query: normalizedQuery)
  }

  /// Compatibility API used by existing views.
  func cities(for countryCode: String) -> [PrayerCity] {
    cities(for: countryCode, query: "", language: preferredLanguage)
  }

  func hasMoreCities(
    countryCode: String,
    query: String = "",
    language: String = "en"
  ) -> Bool {
    let key = makeCityQueryKey(countryCode: countryCode, query: query, language: language)
    return cityNextCursors[key] != nil
  }

  func isLoadingCities(
    countryCode: String,
    query: String = "",
    language: String = "en"
  ) -> Bool {
    let key = makeCityQueryKey(countryCode: countryCode, query: query, language: language)
    return cityTasks[key] != nil
  }

  func cityError(
    countryCode: String,
    query: String = "",
    language: String = "en"
  ) -> String? {
    let key = makeCityQueryKey(countryCode: countryCode, query: query, language: language)
    return cityFailures[key.errorKey]?.localizedDescription
  }

  /// Loads every country page for one language. The aggregate is published
  /// only after all pages validate against the same dataset version.
  func loadCountries(language: String = "en", forceRefresh: Bool = false) async {
    let normalizedLanguage = Self.normalizedLanguage(language)
    preferredLanguage = normalizedLanguage
    if let cached = readCountrySnapshot(language: normalizedLanguage) {
      countries = cached
    }

    if let task = countryTasks[normalizedLanguage] {
      await task.value
      return
    }

    let task = Task { @MainActor [weak self] in
      guard let self else { return }
      await self.refreshCountries(language: normalizedLanguage, forceRefresh: forceRefresh)
    }
    countryTasks[normalizedLanguage] = task
    await task.value
  }

  /// Loads only the first city page. Further pages are fetched explicitly with
  /// `loadMoreCities`, so a country with millions of cities never causes an
  /// unbounded download.
  func loadCities(
    countryCode: String,
    query: String = "",
    language: String = "en",
    forceRefresh: Bool = false
  ) async {
    let normalizedCode = countryCode.uppercased()
    let normalizedLanguage = Self.normalizedLanguage(language)
    guard PrayerCountryCatalog.isAlpha2Code(normalizedCode) else {
      setCityFailure(.invalidCountryCode, for: normalizedCode, query: query, language: normalizedLanguage)
      return
    }
    guard let normalizedQuery = Self.normalizedQuery(query) else {
      setCityFailure(.invalidQuery, for: normalizedCode, query: query, language: normalizedLanguage)
      return
    }

    preferredLanguage = normalizedLanguage
    let key = CityQueryKey(
      countryCode: normalizedCode,
      query: normalizedQuery,
      language: normalizedLanguage)

    if let task = cityTasks[key] {
      await task.value
      return
    }

    let task = Task { @MainActor [weak self] in
      guard let self else { return }
      await self.refreshCities(
        key: key,
        forceRefresh: forceRefresh,
        retryDatasetChange: true)
    }
    cityTasks[key] = task
    await task.value
  }

  func loadMoreCities(
    countryCode: String,
    query: String = "",
    language: String = "en"
  ) async {
    let normalizedCode = countryCode.uppercased()
    let normalizedLanguage = Self.normalizedLanguage(language)
    guard PrayerCountryCatalog.isAlpha2Code(normalizedCode) else {
      setCityFailure(.invalidCountryCode, for: normalizedCode, query: query, language: normalizedLanguage)
      return
    }
    guard let normalizedQuery = Self.normalizedQuery(query) else {
      setCityFailure(.invalidQuery, for: normalizedCode, query: query, language: normalizedLanguage)
      return
    }

    let key = CityQueryKey(
      countryCode: normalizedCode,
      query: normalizedQuery,
      language: normalizedLanguage)
    guard let cursor = cityNextCursors[key] else {
      if citiesByQuery[key] == nil {
        await loadCities(
          countryCode: normalizedCode,
          query: normalizedQuery,
          language: normalizedLanguage)
      }
      return
    }

    if let task = cityTasks[key] {
      await task.value
      return
    }

    let task = Task { @MainActor [weak self] in
      guard let self else { return }
      await self.refreshCityPage(
        key: key,
        cursor: cursor,
        retryDatasetChange: true)
    }
    cityTasks[key] = task
    await task.value
  }

  nonisolated static func isValidCityQuery(_ query: String) -> Bool {
    normalizedQuery(query) != nil
  }

  nonisolated static func normalizedCityQuery(_ query: String) -> String? {
    normalizedQuery(query)
  }

  nonisolated static func configuredBaseURL(bundle: Bundle = .main) -> URL? {
    guard let rawValue = bundle.object(forInfoDictionaryKey: "LocationCatalogBaseURL") as? String else {
      return nil
    }
    return normalizedBaseURL(URL(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)))
  }

  nonisolated static func defaultCacheDirectory(
    fileManager: FileManager = .default,
    bundleIdentifier: String? = Bundle.main.bundleIdentifier
  ) -> URL {
    let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first ?? fileManager.temporaryDirectory
    return applicationSupport
      .appendingPathComponent(bundleIdentifier ?? "azkarify", isDirectory: true)
      .appendingPathComponent("LocationCatalog", isDirectory: true)
  }

  // MARK: Loading

  private func refreshCountries(language: String, forceRefresh: Bool) async {
    countriesLoading = true
    countriesError = nil
    countriesFailure = nil
    defer {
      countriesLoading = false
      countryTasks[language] = nil
    }

    // An empty build-time URL means the optional catalog is disabled. Keep the
    // bundled list silent and usable; a configured URL with no usable transport
    // is reported as an actual service failure below.
    guard baseURL != nil else { return }

    do {
      var attempt = 0
      while true {
        do {
          let pages = try await loadAllCountryPages(
            language: language,
            forceRefresh: forceRefresh || attempt > 0)
          var allCountries: [PrayerCountry] = []
          var seenCodes = Set<String>()
          for page in pages {
            for country in page.items {
              guard seenCodes.insert(country.code).inserted else {
                throw LocationCatalogError.invalidPayload
              }
              allCountries.append(country)
            }
          }
          guard !allCountries.isEmpty else { throw LocationCatalogError.invalidPayload }
          countries = allCountries
          writeCountrySnapshot(allCountries, language: language)
          return
        } catch LocationCatalogError.datasetChanged where attempt == 0 {
          attempt += 1
          continue
        }
      }
    } catch {
      recordCountryFailure(asCatalogError(error))
    }
  }

  private func loadAllCountryPages(
    language: String,
    forceRefresh: Bool
  ) async throws -> [CountryPage] {
    var pages: [CountryPage] = []
    var cursor: String?
    var seenCursors = Set<String>()
    var datasetVersion: String?

    repeat {
      let page = try await loadCountryPage(
        language: language,
        cursor: cursor,
        forceRefresh: forceRefresh)
      if let datasetVersion, datasetVersion != page.datasetVersion {
        throw LocationCatalogError.datasetChanged
      }
      datasetVersion = page.datasetVersion
      pages.append(page)
      guard let nextCursor = page.nextCursor else { break }
      guard seenCursors.insert(nextCursor).inserted else {
        throw LocationCatalogError.invalidPayload
      }
      cursor = nextCursor
    } while true

    return pages
  }

  private func loadCountryPage(
    language: String,
    cursor: String?,
    forceRefresh: Bool
  ) async throws -> CountryPage {
    let resource = Resource.countries(language: language, cursor: cursor)
    let cached = readCountryPage(language: language, cursor: cursor)
    if let cached, !forceRefresh, isFresh(cached.fetchedAt) { return cached }

    guard let baseURL else {
      if let cached { return cached }
      throw LocationCatalogError.unavailable
    }
    guard let transport else {
      if let cached { return cached }
      throw LocationCatalogError.unavailable
    }

    let result = try await fetch(
      resource: resource,
      endpoint: baseURL.appendingPathComponent("countries.json"),
      language: language,
      query: nil,
      limit: Self.countryPageSize,
      cursor: cursor,
      etag: cached?.etag,
      transport: transport)

    switch result {
    case .notModified(let etag):
      guard let cached else { throw LocationCatalogError.missingCacheForNotModifiedResponse }
      let refreshed = cached.with(fetchedAt: now(), etag: etag ?? cached.etag)
      writeCountryPage(refreshed, language: language, cursor: cursor)
      return refreshed
    case .body(let data, let etag, let headerDatasetVersion):
      let page = try decodeCountries(
        data,
        language: language,
        etag: etag,
        headerDatasetVersion: headerDatasetVersion)
      writeCountryPage(page, language: language, cursor: cursor)
      return page
    }
  }

  private func refreshCities(
    key: CityQueryKey,
    forceRefresh: Bool,
    retryDatasetChange: Bool
  ) async {
    loadingCountryCodes.insert(key.countryCode)
    setCityFailure(nil, for: key.countryCode, query: key.query, language: key.language)
    defer {
      loadingCountryCodes.remove(key.countryCode)
      cityTasks[key] = nil
    }

    do {
      try await loadInitialCityPage(key: key, forceRefresh: forceRefresh)
    } catch LocationCatalogError.datasetChanged where retryDatasetChange {
      clearCityAggregate(key)
      await refreshCities(key: key, forceRefresh: true, retryDatasetChange: false)
    } catch {
      recordCityFailure(asCatalogError(error), for: key)
    }
  }

  private func loadInitialCityPage(key: CityQueryKey, forceRefresh: Bool) async throws {
    let cached = readCityPage(
      countryCode: key.countryCode,
      query: key.query,
      language: key.language,
      cursor: nil)
    if let cached, !forceRefresh, isFresh(cached.fetchedAt) {
      publishCityPage(cached, key: key, cursor: nil, replacingAggregate: true)
      return
    }

    guard let baseURL else {
      if let cached {
        publishCityPage(cached, key: key, cursor: nil, replacingAggregate: true)
      }
      return
    }
    guard let transport else {
      if let cached {
        publishCityPage(cached, key: key, cursor: nil, replacingAggregate: true)
        return
      }
      throw LocationCatalogError.unavailable
    }

    let result = try await fetch(
      resource: .cities(
        countryCode: key.countryCode,
        language: key.language,
        query: key.query,
        cursor: nil),
      endpoint: baseURL
        .appendingPathComponent("countries")
        .appendingPathComponent(key.countryCode)
        .appendingPathComponent("cities.json"),
      language: key.language,
      query: key.query,
      limit: Self.cityPageSize,
      cursor: nil,
      etag: cached?.etag,
      transport: transport)

    switch result {
    case .notModified(let etag):
      guard let cached else { throw LocationCatalogError.missingCacheForNotModifiedResponse }
      let refreshed = cached.with(fetchedAt: now(), etag: etag ?? cached.etag)
      writeCityPage(refreshed, key: key, cursor: nil)
      publishCityPage(refreshed, key: key, cursor: nil, replacingAggregate: true)
    case .body(let data, let etag, let headerDatasetVersion):
      let page = try decodeCities(
        data,
        expectedCountryCode: key.countryCode,
        language: key.language,
        etag: etag,
        headerDatasetVersion: headerDatasetVersion)
      writeCityPage(page, key: key, cursor: nil)
      publishCityPage(page, key: key, cursor: nil, replacingAggregate: true)
    }
  }

  private func refreshCityPage(
    key: CityQueryKey,
    cursor: String,
    retryDatasetChange: Bool
  ) async {
    loadingCountryCodes.insert(key.countryCode)
    setCityFailure(nil, for: key.countryCode, query: key.query, language: key.language)
    defer {
      loadingCountryCodes.remove(key.countryCode)
      cityTasks[key] = nil
    }

    do {
      guard let baseURL, let transport else { throw LocationCatalogError.unavailable }
      let pageKey = CityPageKey(queryKey: key, cursor: cursor)
      let cached = readCityPage(
        countryCode: key.countryCode,
        query: key.query,
        language: key.language,
        cursor: cursor)
      let result = try await fetch(
        resource: .cities(
          countryCode: key.countryCode,
          language: key.language,
          query: key.query,
          cursor: cursor),
        endpoint: baseURL
          .appendingPathComponent("countries")
          .appendingPathComponent(key.countryCode)
          .appendingPathComponent("cities.json"),
        language: key.language,
        query: key.query,
        limit: Self.cityPageSize,
        cursor: cursor,
        etag: cached?.etag,
        transport: transport)

      let page: CityPage
      switch result {
      case .notModified(let etag):
        guard let cached else { throw LocationCatalogError.missingCacheForNotModifiedResponse }
        page = cached.with(fetchedAt: now(), etag: etag ?? cached.etag)
        writeCityPage(page, key: key, cursor: cursor)
      case .body(let data, let etag, let headerDatasetVersion):
        page = try decodeCities(
          data,
          expectedCountryCode: key.countryCode,
          language: key.language,
          etag: etag,
          headerDatasetVersion: headerDatasetVersion)
        writeCityPage(page, key: key, cursor: cursor)
      }

      guard let existingVersion = cityDatasetVersions[key], existingVersion == page.datasetVersion,
        let existing = citiesByQuery[key]
      else { throw LocationCatalogError.datasetChanged }

      var merged = existing
      let existingIDs = Set(existing.map(\.id))
      merged.append(contentsOf: page.items.filter { !existingIDs.contains($0.id) })
      citiesByQuery[key] = merged
      cityDatasetVersions[key] = page.datasetVersion
      if let nextCursor = page.nextCursor {
        cityNextCursors[key] = nextCursor
      } else {
        cityNextCursors[key] = nil
      }
      if let etag = page.etag { cityPageETags[pageKey] = etag }
      cityPageFetchedAt[pageKey] = page.fetchedAt
    } catch LocationCatalogError.datasetChanged where retryDatasetChange {
      clearCityAggregate(key)
      await refreshCities(key: key, forceRefresh: true, retryDatasetChange: false)
    } catch {
      recordCityFailure(asCatalogError(error), for: key)
    }
  }

  // MARK: Transport and decoding

  private func fetch(
    resource: Resource,
    endpoint: URL,
    language: String,
    query: String?,
    limit: Int,
    cursor: String?,
    etag: String?,
    transport: CountriesAPITransport
  ) async throws -> FetchResult {
    guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
      throw LocationCatalogError.invalidHTTPResponse
    }
    var queryItems = [URLQueryItem(name: "lang", value: language)]
    if let query, !query.isEmpty {
      queryItems.append(URLQueryItem(name: "q", value: query))
    }
    queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
    if let cursor {
      queryItems.append(URLQueryItem(name: "cursor", value: cursor))
    }
    components.queryItems = queryItems
    guard let url = components.url else { throw LocationCatalogError.invalidHTTPResponse }

    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
    request.httpMethod = "GET"
    request.setValue(language, forHTTPHeaderField: "Accept-Language")
    if let etag, !etag.isEmpty {
      request.setValue(etag, forHTTPHeaderField: "If-None-Match")
    }

    let data: Data
    let response: HTTPURLResponse
    do {
      (data, response) = try await transport.data(for: request)
    } catch {
      // The authenticated client reports 409 dataset changes and unsupported
      // App Attest devices as typed errors before a response reaches us.
      throw asCatalogError(error)
    }
    guard data.count <= Self.maximumResponseBytes else {
      throw LocationCatalogError.responseTooLarge
    }

    let responseETag = response.value(forHTTPHeaderField: "ETag")
      .flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    let datasetVersion = response.value(forHTTPHeaderField: "X-Dataset-Version")
      .flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }

    switch response.statusCode {
    case 200..<300:
      return .body(data: data, etag: responseETag, headerDatasetVersion: datasetVersion)
    case 304:
      return .notModified(etag: responseETag)
    case 409:
      throw LocationCatalogError.datasetChanged
    default:
      throw LocationCatalogError.httpStatus(response.statusCode)
    }
  }

  private func decodeCountries(
    _ data: Data,
    language: String,
    etag: String?,
    headerDatasetVersion: String?
  ) throws -> CountryPage {
    let response = try JSONDecoder().decode(CountriesResponse.self, from: data)
    guard response.meta.language == language,
      !response.meta.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      response.meta.coverage == "world" || response.meta.coverage == "subset",
      headerDatasetVersion == nil || headerDatasetVersion == response.meta.version
    else { throw LocationCatalogError.invalidPayload }

    var seenCodes = Set<String>()
    var countries: [PrayerCountry] = []
    countries.reserveCapacity(response.data.count)
    for country in response.data {
      let code = country.code.uppercased()
      guard PrayerCountryCatalog.isAlpha2Code(code), seenCodes.insert(code).inserted else {
        throw LocationCatalogError.invalidPayload
      }
      let englishName = country.names.en.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !englishName.isEmpty else { throw LocationCatalogError.invalidPayload }
      let arabicName = (country.names.ar ?? englishName)
        .trimmingCharacters(in: .whitespacesAndNewlines)
      guard !arabicName.isEmpty else { throw LocationCatalogError.invalidPayload }
      let method = try prayerMethod(from: country.prayerCalculationMethod)
      countries.append(PrayerCountry(
        code: code,
        englishName: englishName,
        arabicName: arabicName,
        flag: country.flag,
        method: method))
    }

    return CountryPage(
      items: countries,
      nextCursor: response.meta.nextCursor,
      datasetVersion: headerDatasetVersion ?? response.meta.version,
      etag: etag,
      data: data,
      fetchedAt: now())
  }

  private func decodeCities(
    _ data: Data,
    expectedCountryCode: String,
    language: String,
    etag: String?,
    headerDatasetVersion: String?
  ) throws -> CityPage {
    let response = try JSONDecoder().decode(CitiesResponse.self, from: data)
    guard response.meta.language == language,
      !response.meta.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      response.meta.coverage == nil || response.meta.coverage == "world" || response.meta.coverage == "subset",
      headerDatasetVersion == nil || headerDatasetVersion == response.meta.version
    else { throw LocationCatalogError.invalidPayload }

    let expected = expectedCountryCode.uppercased()
    var seenIDs = Set<String>()
    var cities: [PrayerCity] = []
    cities.reserveCapacity(response.data.count)
    for city in response.data {
      guard city.id > 0,
        city.countryCode.uppercased() == expected,
        seenIDs.insert(String(city.id)).inserted,
        city.location.latitude.isFinite,
        (-90...90).contains(city.location.latitude),
        city.location.longitude.isFinite,
        (-180...180).contains(city.location.longitude),
        !city.timezone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        TimeZone(identifier: city.timezone) != nil
      else { throw LocationCatalogError.invalidPayload }

      let englishName = city.names.en.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !englishName.isEmpty else { throw LocationCatalogError.invalidPayload }
      let arabicName = (city.names.ar ?? englishName)
        .trimmingCharacters(in: .whitespacesAndNewlines)
      guard !arabicName.isEmpty else { throw LocationCatalogError.invalidPayload }
      let method = try prayerMethod(from: city.prayerCalculationMethod)
      cities.append(PrayerCity(
        id: String(city.id),
        englishName: englishName,
        arabicName: arabicName,
        countryCode: expected,
        latitude: city.location.latitude,
        longitude: city.location.longitude,
        timeZone: city.timezone,
        method: method,
        region: city.region))
    }

    return CityPage(
      items: cities,
      nextCursor: response.meta.nextCursor,
      datasetVersion: headerDatasetVersion ?? response.meta.version,
      etag: etag,
      data: data,
      fetchedAt: now())
  }

  private func prayerMethod(from rawValue: String?) throws -> PrayerCalculationMethod {
    // The service documents null as the default MWL method. Unknown non-null
    // values remain invalid so a server typo cannot silently alter prayer times.
    guard let rawValue else { return .muslimWorldLeague }
    switch rawValue {
    case "muslim_world_league": return .muslimWorldLeague
    case "egyptian": return .egyptian
    case "karachi": return .karachi
    case "umm_al_qura": return .ummAlQura
    case "dubai": return .dubai
    case "qatar": return .qatar
    case "kuwait": return .kuwait
    case "singapore": return .singapore
    case "north_america": return .northAmerica
    case "tehran": return .tehran
    case "turkey": return .turkey
    default: throw LocationCatalogError.invalidPayload
    }
  }

  // MARK: Cache

  private func publishCityPage(
    _ page: CityPage,
    key: CityQueryKey,
    cursor: String?,
    replacingAggregate: Bool
  ) {
    if replacingAggregate {
      citiesByQuery[key] = page.items
      cityDatasetVersions[key] = page.datasetVersion
    }
    if let nextCursor = page.nextCursor {
      cityNextCursors[key] = nextCursor
    } else {
      cityNextCursors[key] = nil
    }
    let pageKey = CityPageKey(queryKey: key, cursor: cursor)
    if let etag = page.etag { cityPageETags[pageKey] = etag }
    cityPageFetchedAt[pageKey] = page.fetchedAt
  }

  private func clearCityAggregate(_ key: CityQueryKey) {
    citiesByQuery[key] = nil
    cityNextCursors[key] = nil
    cityDatasetVersions[key] = nil
  }

  private func readCountryPage(language: String, cursor: String?) -> CountryPage? {
    guard let envelope = readCache(resource: .countries(language: language, cursor: cursor)) else {
      return nil
    }
    guard let page = try? decodeCountries(
      envelope.data,
      language: language,
      etag: envelope.etag,
      headerDatasetVersion: envelope.datasetVersion)
    else { return nil }
    return page.with(
      fetchedAt: envelope.fetchedAt,
      etag: envelope.etag,
      nextCursor: envelope.nextCursor,
      datasetVersion: envelope.datasetVersion)
  }

  private func readCountrySnapshot(language: String) -> [PrayerCountry]? {
    let url = cacheDirectory.appendingPathComponent("countries-complete-\(language).json")
    guard let data = try? Data(contentsOf: url),
      let snapshot = try? JSONDecoder().decode([PrayerCountry].self, from: data),
      !snapshot.isEmpty,
      Set(snapshot.map(\.code)).count == snapshot.count,
      snapshot.allSatisfy({ PrayerCountryCatalog.isAlpha2Code($0.code) && !$0.englishName.isEmpty })
    else { return nil }
    return snapshot
  }

  private func writeCountrySnapshot(_ countries: [PrayerCountry], language: String) {
    guard let data = try? JSONEncoder().encode(countries) else { return }
    do {
      try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
      try data.write(
        to: cacheDirectory.appendingPathComponent("countries-complete-\(language).json"),
        options: .atomic)
    } catch {
      // A valid in-memory result remains usable when disk storage is unavailable.
    }
  }

  private func readCompleteCountryCache(language: String) -> [PrayerCountry]? {
    var allCountries: [PrayerCountry] = []
    var seenCodes = Set<String>()
    var seenCursors = Set<String>()
    var cursor: String?
    var version: String?

    repeat {
      guard let page = readCountryPage(language: language, cursor: cursor) else { return nil }
      if let version, version != page.datasetVersion { return nil }
      version = page.datasetVersion
      for country in page.items {
        guard seenCodes.insert(country.code).inserted else { return nil }
        allCountries.append(country)
      }
      guard let nextCursor = page.nextCursor else { break }
      guard seenCursors.insert(nextCursor).inserted else { return nil }
      cursor = nextCursor
    } while true

    return allCountries.isEmpty ? nil : allCountries
  }

  private func readCityPage(
    countryCode: String,
    query: String,
    language: String,
    cursor: String?
  ) -> CityPage? {
    guard let envelope = readCache(resource: .cities(
      countryCode: countryCode,
      language: language,
      query: query,
      cursor: cursor)) else { return nil }
    guard let page = try? decodeCities(
      envelope.data,
      expectedCountryCode: countryCode,
      language: language,
      etag: envelope.etag,
      headerDatasetVersion: envelope.datasetVersion)
    else { return nil }
    return page.with(
      fetchedAt: envelope.fetchedAt,
      etag: envelope.etag,
      nextCursor: envelope.nextCursor,
      datasetVersion: envelope.datasetVersion)
  }

  private func writeCountryPage(_ page: CountryPage, language: String, cursor: String?) {
    writeCache(
      CacheEnvelope(
        etag: page.etag,
        datasetVersion: page.datasetVersion,
        nextCursor: page.nextCursor,
        data: page.data,
        fetchedAt: page.fetchedAt),
      resource: .countries(language: language, cursor: cursor))
  }

  private func writeCityPage(_ page: CityPage, key: CityQueryKey, cursor: String?) {
    writeCache(
      CacheEnvelope(
        etag: page.etag,
        datasetVersion: page.datasetVersion,
        nextCursor: page.nextCursor,
        data: page.data,
        fetchedAt: page.fetchedAt),
      resource: .cities(
        countryCode: key.countryCode,
        language: key.language,
        query: key.query,
        cursor: cursor))
  }

  private func readCache(resource: Resource) -> CacheEnvelope? {
    let url = cacheDirectory.appendingPathComponent(resource.fileName)
    guard let data = try? Data(contentsOf: url) else { return nil }
    guard let envelope = try? JSONDecoder().decode(CacheEnvelope.self, from: data),
      envelope.data.count <= Self.maximumResponseBytes
    else { return nil }
    return envelope
  }

  private func writeCache(_ envelope: CacheEnvelope, resource: Resource) {
    guard let data = try? JSONEncoder().encode(envelope) else { return }
    do {
      try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
      try data.write(to: cacheDirectory.appendingPathComponent(resource.fileName), options: .atomic)
    } catch {
      // A cache write must never make a valid network response unusable.
    }
  }

  private func isFresh(_ date: Date) -> Bool {
    let age = now().timeIntervalSince(date)
    return age >= 0 && age <= Self.cacheTimeToLive
  }

  // MARK: Helpers

  private func makeCityQueryKey(countryCode: String, query: String, language: String) -> CityQueryKey {
    CityQueryKey(
      countryCode: countryCode.uppercased(),
      query: Self.normalizedQuery(query) ?? "",
      language: Self.normalizedLanguage(language))
  }

  private func setCityFailure(
    _ failure: LocationCatalogError?,
    for countryCode: String,
    query: String,
    language: String
  ) {
    let key = makeCityQueryKey(countryCode: countryCode, query: query, language: language)
    if let failure {
      cityFailures[key.errorKey] = failure
      latestCityErrorKeys[key.countryCode] = key.errorKey
      cityErrors[countryCode] = failure.localizedDescription
    } else {
      cityFailures[key.errorKey] = nil
      if latestCityErrorKeys[key.countryCode] == key.errorKey {
        latestCityErrorKeys[key.countryCode] = nil
        cityErrors[countryCode] = nil
      }
    }
  }

  private func recordCityFailure(_ failure: LocationCatalogError, for key: CityQueryKey) {
    cityFailures[key.errorKey] = failure
    latestCityErrorKeys[key.countryCode] = key.errorKey
    cityErrors[key.countryCode] = failure.localizedDescription
  }

  private func recordCountryFailure(_ failure: LocationCatalogError) {
    countriesFailure = failure
    countriesError = failure.localizedDescription
  }

  private func asCatalogError(_ error: Error) -> LocationCatalogError {
    if let error = error as? LocationCatalogError { return error }
    if let clientError = error as? CountriesAPIClient.ClientError {
      switch clientError {
      case .unsupportedDevice:
        return .unsupportedSimulator
      case .httpStatus(let status, let code):
        if status == 409, code == "dataset_changed" { return .datasetChanged }
        return .httpStatus(status)
      case .transport(let underlying):
        return asCatalogError(underlying)
      default:
        return .unavailable
      }
    }
    if error is URLError { return .unavailable }
    return .unavailable
  }

  nonisolated static func normalizedLanguage(_ language: String) -> String {
    language.lowercased().hasPrefix("ar") ? "ar" : "en"
  }

  nonisolated static func normalizedQuery(_ query: String) -> String? {
    let normalized = query
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .split(whereSeparator: { $0.isWhitespace })
      .joined(separator: " ")
      .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    guard normalized.isEmpty || (normalized.count >= 2 && normalized.count <= 64) else { return nil }
    guard normalized.split(separator: " ").count <= 5 else { return nil }
    return normalized
  }

  nonisolated private static func filterCities(_ cities: [PrayerCity], query: String) -> [PrayerCity] {
    let normalizedQuery = query.folding(
      options: [.caseInsensitive, .diacriticInsensitive],
      locale: Locale(identifier: "en_US_POSIX"))
    return cities.filter { city in
      [city.englishName, city.arabicName].map {
        $0.folding(
          options: [.caseInsensitive, .diacriticInsensitive],
          locale: Locale(identifier: "en_US_POSIX"))
      }.contains { $0.hasPrefix(normalizedQuery) || $0.contains(normalizedQuery) }
    }
  }

  nonisolated private static func normalizedBaseURL(_ url: URL?) -> URL? {
    guard let url, url.scheme?.lowercased() == "https", url.host != nil else { return nil }
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let path = components?.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
    guard path == "v1" else { return nil }
    components?.path = "/v1"
    components?.query = nil
    components?.fragment = nil
    return components?.url
  }

  nonisolated private static func cacheNamespace(for baseURL: URL?) -> String {
    stableHash(baseURL?.absoluteString ?? "disabled")
  }

  nonisolated private static func stableHash(_ value: String) -> String {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in value.utf8 {
      hash ^= UInt64(byte)
      hash &*= 1_099_511_628_211
    }
    return String(format: "%016llx", hash)
  }

  // MARK: Types

  private struct CityQueryKey: Hashable, Sendable {
    let countryCode: String
    let query: String
    let language: String

    var errorKey: String { "\(countryCode)|\(language)|\(query)" }
  }

  private struct CityPageKey: Hashable, Sendable {
    let queryKey: CityQueryKey
    let cursor: String?
  }

  private enum Resource {
    case countries(language: String, cursor: String?)
    case cities(countryCode: String, language: String, query: String, cursor: String?)

    var fileName: String {
      switch self {
      case .countries(let language, let cursor):
        return "page-" + LocationCatalogStore.stableHash(
          "countries|\(language)|\(cursor ?? "<first>")") + ".cache"
      case .cities(let countryCode, let language, let query, let cursor):
        return "page-" + LocationCatalogStore.stableHash(
          "cities|\(countryCode)|\(language)|\(query)|\(cursor ?? "<first>")") + ".cache"
      }
    }
  }

  private struct CacheEnvelope: Codable {
    let etag: String?
    let datasetVersion: String
    let nextCursor: String?
    let data: Data
    let fetchedAt: Date
  }

  private struct CountryPage {
    let items: [PrayerCountry]
    let nextCursor: String?
    let datasetVersion: String
    let etag: String?
    let data: Data
    let fetchedAt: Date

    func with(
      fetchedAt: Date,
      etag: String?,
      nextCursor: String? = nil,
      datasetVersion: String? = nil
    ) -> CountryPage {
      CountryPage(
        items: items,
        nextCursor: nextCursor ?? self.nextCursor,
        datasetVersion: datasetVersion ?? self.datasetVersion,
        etag: etag,
        data: data,
        fetchedAt: fetchedAt)
    }
  }

  private struct CityPage {
    let items: [PrayerCity]
    let nextCursor: String?
    let datasetVersion: String
    let etag: String?
    let data: Data
    let fetchedAt: Date

    func with(
      fetchedAt: Date,
      etag: String?,
      nextCursor: String? = nil,
      datasetVersion: String? = nil
    ) -> CityPage {
      CityPage(
        items: items,
        nextCursor: nextCursor ?? self.nextCursor,
        datasetVersion: datasetVersion ?? self.datasetVersion,
        etag: etag,
        data: data,
        fetchedAt: fetchedAt)
    }
  }

  private struct CountriesResponse: Decodable {
    let data: [CountryPayload]
    let meta: PageMeta
  }

  private struct CountryPayload: Decodable {
    let code: String
    let name: String
    let flag: String?
    let prayerCalculationMethod: String?
    let names: LocalizedNamesPayload
    let nameLanguage: String?
  }

  private struct CitiesResponse: Decodable {
    let data: [CityPayload]
    let meta: PageMeta
  }

  private struct CityPayload: Decodable {
    let id: Int
    let countryCode: String
    let name: String
    let region: String?
    let location: LocationPayload
    let timezone: String
    let prayerCalculationMethod: String?
    let names: LocalizedNamesPayload
    let nameLanguage: String?
  }

  private struct LocationPayload: Decodable {
    let latitude: Double
    let longitude: Double
  }

  private struct LocalizedNamesPayload: Decodable {
    let en: String
    let ar: String?
  }

  private struct PageMeta: Decodable {
    let language: String
    let version: String
    let coverage: String?
    let nextCursor: String?
    let total: Int?
  }

  private enum FetchResult {
    case body(data: Data, etag: String?, headerDatasetVersion: String?)
    case notModified(etag: String?)
  }
}
