import Foundation
import Testing

@testable import azkarify

@Suite(.serialized)
@MainActor
struct LocationCatalogTests {
  @Test func disabledNetworkUsesBundledCountriesAndCities() async {
    let store = LocationCatalogStore(
      baseURL: nil,
      cacheDirectory: temporaryDirectory())

    #expect(!store.countries.isEmpty)
    #expect(store.cities(for: "AE").map(\.id) == ["Dubai", "Abu Dhabi"])

    await store.loadCountries()
    await store.loadCities(countryCode: "AE")

    #expect(store.countriesFailure == nil)
    #expect(store.cityFailures.isEmpty)
  }

  @Test func decodesServerSchemaAndUsesDocumentedFallbacks() async {
    let transport = StubTransport(responses: [
      .json("""
      {
        "data":[{"code":"AE","name":"United Arab Emirates","flag":"🇦🇪","prayerCalculationMethod":null,"names":{"en":"United Arab Emirates","ar":null},"nameLanguage":"en"}],
        "meta":{"language":"en","version":"dataset-1","coverage":"subset","nextCursor":null,"total":1}
      }
      """),
      .json("""
      {
        "data":[{"id":101,"countryCode":"AE","name":"Dubai","region":"Dubai","location":{"latitude":25.2048,"longitude":55.2708},"timezone":"Asia/Dubai","prayerCalculationMethod":null,"names":{"en":"Dubai","ar":null},"nameLanguage":"en"}],
        "meta":{"language":"en","version":"dataset-1","coverage":"subset","nextCursor":null}
      }
      """)
    ])
    let store = LocationCatalogStore(
      baseURL: apiBaseURL,
      cacheDirectory: temporaryDirectory(),
      transport: transport)

    await store.loadCountries(language: "en")
    await store.loadCities(countryCode: "ae", language: "en")

    #expect(store.countries.map(\.code) == ["AE"])
    #expect(store.countries[0].name(language: "ar") == "United Arab Emirates")
    #expect(store.countries[0].flag == "🇦🇪")
    #expect(store.countries[0].method == .muslimWorldLeague)
    #expect(store.cities(for: "AE", language: "en").map(\.id) == ["101"])
    #expect(store.cities(for: "AE", language: "en")[0].arabicName == "Dubai")
    #expect(store.cities(for: "AE", language: "en")[0].region == "Dubai")
    #expect(store.cities(for: "AE", language: "en")[0].method == .muslimWorldLeague)

    let requests = transport.requests
    #expect(requests.count == 2)
    #expect(requests[0].value(forHTTPHeaderField: "Accept-Language") == "en")
    #expect(requests[1].url?.path == "/v1/countries/AE/cities.json")
  }

  @Test func countryPaginationFetchesAllPagesAtServerLimit() async {
    let transport = StubTransport(responses: [
      .json("""
      {"data":[{"code":"AE","name":"United Arab Emirates","flag":"🇦🇪","prayerCalculationMethod":"dubai","names":{"en":"United Arab Emirates","ar":"الإمارات"},"nameLanguage":"en"}],"meta":{"language":"en","version":"v1","coverage":"world","nextCursor":"page-2","total":2}}
      """),
      .json("""
      {"data":[{"code":"XK","name":"Kosovo","flag":"🇽🇰","prayerCalculationMethod":null,"names":{"en":"Kosovo","ar":null},"nameLanguage":"en"}],"meta":{"language":"en","version":"v1","coverage":"world","nextCursor":null,"total":2}}
      """)
    ])
    let store = LocationCatalogStore(
      baseURL: apiBaseURL,
      cacheDirectory: temporaryDirectory(),
      transport: transport)

    await store.loadCountries(language: "en")

    #expect(store.countries.map(\.code) == ["AE", "XK"])
    let requests = transport.requests
    #expect(requests.count == 2)
    #expect(queryValue("limit", in: requests[0]) == "250")
    #expect(queryValue("cursor", in: requests[1]) == "page-2")
  }

  @Test func citySearchAndPaginationRemainQueryScoped() async {
    let transport = StubTransport(responses: [
      .json("""
      {"data":[{"id":1,"countryCode":"AE","name":"Abu Dhabi","region":null,"location":{"latitude":24.45,"longitude":54.37},"timezone":"Asia/Dubai","prayerCalculationMethod":"dubai","names":{"en":"Abu Dhabi","ar":"أبو ظبي"},"nameLanguage":"en"}],"meta":{"language":"en","version":"v1","coverage":"subset","nextCursor":"city-2"}}
      """),
      .json("""
      {"data":[{"id":2,"countryCode":"AE","name":"Abu Dhabi Central","region":"Abu Dhabi","location":{"latitude":24.46,"longitude":54.38},"timezone":"Asia/Dubai","prayerCalculationMethod":"dubai","names":{"en":"Abu Dhabi Central","ar":"أبو ظبي الوسطى"},"nameLanguage":"en"}],"meta":{"language":"en","version":"v1","coverage":"subset","nextCursor":null}}
      """)
    ])
    let store = LocationCatalogStore(
      baseURL: apiBaseURL,
      cacheDirectory: temporaryDirectory(),
      transport: transport)

    await store.loadCities(countryCode: "AE", query: "  abu   ", language: "en")
    #expect(store.cities(for: "AE", query: "abu", language: "en").map(\.id) == ["1"])
    #expect(store.hasMoreCities(countryCode: "AE", query: "abu", language: "en"))

    await store.loadMoreCities(countryCode: "AE", query: "abu", language: "en")
    #expect(store.cities(for: "AE", query: "abu", language: "en").map(\.id) == ["1", "2"])
    #expect(!store.hasMoreCities(countryCode: "AE", query: "abu", language: "en"))

    let requests = transport.requests
    #expect(queryValue("q", in: requests[0]) == "abu")
    #expect(queryValue("limit", in: requests[0]) == "100")
    #expect(queryValue("cursor", in: requests[1]) == "city-2")
  }

  @Test func etagRefreshUsesAuthenticatedTransportAndKeepsCachedBody() async {
    let directory = temporaryDirectory()
    let clock = TestClock(date: Date(timeIntervalSince1970: 1_000_000))
    let firstTransport = StubTransport(responses: [
      .response(
        status: 200,
        headers: ["ETag": "\"countries-v1\""],
        body: Data("""
        {"data":[{"code":"AE","name":"United Arab Emirates","flag":"🇦🇪","prayerCalculationMethod":null,"names":{"en":"United Arab Emirates","ar":null},"nameLanguage":"en"}],"meta":{"language":"en","version":"v1","coverage":"subset","nextCursor":null,"total":1}}
        """.utf8))
    ])
    let first = LocationCatalogStore(
      baseURL: apiBaseURL,
      cacheDirectory: directory,
      transport: firstTransport,
      now: { clock.date })
    await first.loadCountries(language: "en")

    clock.date.addTimeInterval(25 * 60 * 60)
    let secondTransport = StubTransport(responses: [
      .response(status: 304, headers: ["ETag": "\"countries-v1\""], body: Data())
    ])
    let second = LocationCatalogStore(
      baseURL: apiBaseURL,
      cacheDirectory: directory,
      transport: secondTransport,
      now: { clock.date })
    await second.loadCountries(language: "en")

    let requests = secondTransport.requests
    #expect(requests.count == 1)
    #expect(requests[0].value(forHTTPHeaderField: "If-None-Match") == "\"countries-v1\"")
    #expect(second.countries.map(\.code) == ["AE"])
    #expect(second.countriesFailure == nil)
  }

  @Test func languageAndBaseURLAreCacheNamespaces() async {
    let directory = temporaryDirectory()
    let englishTransport = StubTransport(responses: [
      .json("""
      {"data":[{"code":"AE","name":"United Arab Emirates","flag":"🇦🇪","prayerCalculationMethod":null,"names":{"en":"United Arab Emirates","ar":"الإمارات"},"nameLanguage":"en"}],"meta":{"language":"en","version":"v1","coverage":"subset","nextCursor":null,"total":1}}
      """)
    ])
    let english = LocationCatalogStore(
      baseURL: apiBaseURL,
      cacheDirectory: directory,
      transport: englishTransport)
    await english.loadCountries(language: "en")

    let arabicTransport = StubTransport(responses: [
      .json("""
      {"data":[{"code":"AE","name":"الإمارات","flag":"🇦🇪","prayerCalculationMethod":null,"names":{"en":"United Arab Emirates","ar":"الإمارات"},"nameLanguage":"ar"}],"meta":{"language":"ar","version":"v1","coverage":"subset","nextCursor":null,"total":1}}
      """)
    ])
    let arabic = LocationCatalogStore(
      baseURL: apiBaseURL,
      cacheDirectory: directory,
      transport: arabicTransport)
    await arabic.loadCountries(language: "ar")

    #expect(arabic.countries[0].name(language: "ar") == "الإمارات")
    let englishRequests = englishTransport.requests
    let arabicRequests = arabicTransport.requests
    #expect(englishRequests[0].value(forHTTPHeaderField: "Accept-Language") == "en")
    #expect(arabicRequests[0].value(forHTTPHeaderField: "Accept-Language") == "ar")
  }

  @Test func unknownMethodsKeepBundledCities() async {
    let transport = StubTransport(responses: [
      .json("""
      {"data":[{"id":900,"countryCode":"AE","name":"Broken City","region":null,"location":{"latitude":25,"longitude":55},"timezone":"Asia/Dubai","prayerCalculationMethod":"made_up","names":{"en":"Broken City","ar":null},"nameLanguage":"en"}],"meta":{"language":"en","version":"v1","coverage":"subset","nextCursor":null}}
      """)
    ])
    let store = LocationCatalogStore(
      baseURL: apiBaseURL,
      cacheDirectory: temporaryDirectory(),
      transport: transport)

    await store.loadCities(countryCode: "AE", language: "en")

    #expect(store.cities(for: "AE").map(\.id) == ["Dubai", "Abu Dhabi"])
    #expect(store.cityError(countryCode: "AE", language: "en") != nil)
  }

  @Test func simulatorFailureIsTypedAndDoesNotMakeAnonymousRequest() async {
    let transport = ThrowingTransport(error: CountriesAPIClient.ClientError.unsupportedDevice)
    let store = LocationCatalogStore(
      baseURL: apiBaseURL,
      cacheDirectory: temporaryDirectory(),
      transport: transport)

    await store.loadCountries(language: "en")

    #expect(store.countriesFailure == .unsupportedSimulator)
    let requestCount = transport.requestCount
    #expect(requestCount == 1)
  }

  @Test func cityQueryValidationMatchesServerLimits() {
    #expect(LocationCatalogStore.normalizedCityQuery("  Abu   Dhabi  ") == "abu dhabi")
    #expect(LocationCatalogStore.isValidCityQuery("ab"))
    #expect(!LocationCatalogStore.isValidCityQuery("a"))
    #expect(!LocationCatalogStore.isValidCityQuery("one two three four five six"))
    #expect(!LocationCatalogStore.isValidCityQuery(String(repeating: "a", count: 65)))
  }

  @Test func failedCountryRefreshPreservesCompleteSnapshotAcrossRelaunch() async {
    let directory = temporaryDirectory()
    let transport = StubTransport(responses: [
      countryPage(code: "AE", version: "old", cursor: "old-page-2"),
      countryPage(code: "EG", version: "old", cursor: nil),
      countryPage(code: "AE", version: "new", cursor: "new-page-2"),
      .response(status: 503, headers: [:], body: Data()),
    ])
    let store = LocationCatalogStore(baseURL: apiBaseURL, cacheDirectory: directory, transport: transport)
    await store.loadCountries()
    #expect(store.countries.map(\.code) == ["AE", "EG"])
    await store.loadCountries(forceRefresh: true)
    #expect(store.countries.map(\.code) == ["AE", "EG"])
    #expect(store.countriesFailure != nil)
    let restored = LocationCatalogStore(baseURL: apiBaseURL, cacheDirectory: directory, transport: transport)
    #expect(restored.countries.map(\.code) == ["AE", "EG"])
  }

  @Test func authenticatedDatasetChangeRestartsCitiesWithoutMixingVersions() async {
    let transport = StubTransport(responses: [
      cityPage(id: 101, version: "old", cursor: "old-page-2"),
      .failure(.httpStatus(409, code: "dataset_changed")),
      cityPage(id: 202, version: "new", cursor: nil),
    ])
    let store = LocationCatalogStore(baseURL: apiBaseURL, cacheDirectory: temporaryDirectory(), transport: transport)
    await store.loadCities(countryCode: "AE")
    #expect(store.cities(for: "AE").map(\.id) == ["101"])
    await store.loadMoreCities(countryCode: "AE")
    #expect(store.cities(for: "AE").map(\.id) == ["202"])
    #expect(!store.hasMoreCities(countryCode: "AE"))
    #expect(transport.requests.count == 3)
    #expect(queryValue("cursor", in: transport.requests[2]) == nil)
  }

  private func countryPage(code: String, version: String, cursor: String?) -> StubTransport.Response {
    let cursorJSON = cursor.map { "\"\($0)\"" } ?? "null"
    return .json("""
    {"data":[{"code":"\(code)","name":"\(code)","flag":"flag","prayerCalculationMethod":null,"names":{"en":"\(code)","ar":null},"nameLanguage":"en"}],"meta":{"language":"en","version":"\(version)","coverage":"world","nextCursor":\(cursorJSON),"total":2}}
    """)
  }

  private func cityPage(id: Int, version: String, cursor: String?) -> StubTransport.Response {
    let cursorJSON = cursor.map { "\"\($0)\"" } ?? "null"
    return .json("""
    {"data":[{"id":\(id),"countryCode":"AE","name":"Dubai","region":null,"location":{"latitude":25.2048,"longitude":55.2708},"timezone":"Asia/Dubai","prayerCalculationMethod":"dubai","names":{"en":"Dubai","ar":null},"nameLanguage":"en"}],"meta":{"language":"en","version":"\(version)","coverage":"world","nextCursor":\(cursorJSON)}}
    """)
  }

  private var apiBaseURL: URL { URL(string: "https://api.example.test/v1")! }

  private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("LocationCatalogTests-\(UUID().uuidString)", isDirectory: true)
  }

  private func queryValue(_ name: String, in request: URLRequest) -> String? {
    URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first {
      $0.name == name
    }?.value
  }
}

private final class TestClock: @unchecked Sendable {
  var date: Date

  init(date: Date) {
    self.date = date
  }
}

@MainActor
private final class StubTransport: CountriesAPITransport {
  struct Response: Sendable {
    let status: Int
    let headers: [String: String]
    let body: Data
    var error: CountriesAPIClient.ClientError? = nil

    static func failure(_ error: CountriesAPIClient.ClientError) -> Response {
      Response(status: 0, headers: [:], body: Data(), error: error)
    }

    static func json(_ string: String) -> Response {
      Response(status: 200, headers: [:], body: Data(string.utf8))
    }

    static func response(status: Int, headers: [String: String], body: Data) -> Response {
      Response(status: status, headers: headers, body: body)
    }
  }

  private var responses: [Response]
  private(set) var requests: [URLRequest] = []

  init(responses: [Response]) {
    self.responses = responses
  }

  @MainActor
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    requests.append(request)
    guard !responses.isEmpty, let url = request.url else {
      throw URLError(.badServerResponse)
    }
    let next = responses.removeFirst()
    if let error = next.error { throw error }
    let response = HTTPURLResponse(
      url: url,
      statusCode: next.status,
      httpVersion: "HTTP/1.1",
      headerFields: next.headers)!
    return (next.body, response)
  }
}

@MainActor
private final class ThrowingTransport: CountriesAPITransport {
  private(set) var requestCount = 0

  init(error: CountriesAPIClient.ClientError) {}

  @MainActor
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    requestCount += 1
    throw CountriesAPIClient.ClientError.unsupportedDevice
  }
}
