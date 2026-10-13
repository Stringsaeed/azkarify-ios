import SwiftUI

private struct LocationChoiceHeightKey: PreferenceKey {
  static var defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

struct PrayerLocationSheet: View {
  @EnvironmentObject private var store: AzkarStore
  @EnvironmentObject private var prayerSchedule: PrayerScheduleStore
  @EnvironmentObject private var locationCatalog: LocationCatalogStore
  @AppStorage("accent") private var accent = "brown"
  @StateObject private var locationProvider = PrayerLocationProvider()
  @State private var path: [Route] = []
  @State private var navigationID = UUID()
  @State private var choiceHeight: CGFloat = 312
  @State private var citySearch = ""
  @State private var countrySearch = ""
  @State private var countrySearchIsPresented = false
  @State private var selectedCountryCode = PrayerCountryCatalog.defaultCountryCode()
  @State private var restoredCountry = false
  @State private var locationRequestIsActive = false
  @State private var errorMessage: String?

  let onFinish: () -> Void

  private enum Route: Hashable { case countries, cities }
  private var arabic: Bool { store.language == "ar" }
  private func text(_ english: String, _ arabic: String) -> String {
    self.arabic ? arabic : english
  }
  private var country: PrayerCountry? {
    locationCatalog.countries.first { $0.code == selectedCountryCode }
  }
  private var countryName: String {
    country?.name(language: store.language) ?? text("Choose a country", "اختر دولة")
  }
  private var cityQueryIsValid: Bool {
    LocationCatalogStore.normalizedQuery(citySearch) != nil
  }
  private var cities: [PrayerCity] {
    guard country != nil, cityQueryIsValid else { return [] }
    return locationCatalog.cities(for: selectedCountryCode, query: citySearch, language: store.language)
  }
  private var cityError: String? {
    locationCatalog.cityError(countryCode: selectedCountryCode, query: citySearch, language: store.language)
  }
  private var citiesAreLoading: Bool {
    locationCatalog.isLoadingCities(countryCode: selectedCountryCode, query: citySearch, language: store.language)
  }
  private var countries: [PrayerCountry] {
    let query = countrySearch.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return locationCatalog.countries }
    return locationCatalog.countries.filter {
      $0.code.localizedCaseInsensitiveContains(query)
        || $0.englishName.localizedCaseInsensitiveContains(query)
        || $0.arabicName.localizedCaseInsensitiveContains(query)
    }
  }

  var body: some View {
    NavigationStack(path: $path) {
      choiceScreen
        .navigationDestination(for: Route.self) { route in
          switch route {
          case .countries: countryScreen
          case .cities: cityScreen
          }
        }
    }
    .background(AppAppearance.background(accent))
    .id(navigationID)
    .font(AppAppearance.font(size: 17))
    .tint(AppAppearance.accent(accent))
    .environment(\.layoutDirection, arabic ? .rightToLeft : .leftToRight)
    .presentationDetents(path.isEmpty ? [.height(choiceHeight)] : [.large])
    .presentationDragIndicator(.visible)
    .onPreferenceChange(LocationChoiceHeightKey.self) { height in
      guard height > 0 else { return }
      choiceHeight = max(height, 280)
    }
    .onAppear(perform: restoreCountrySelection)
    .onChange(of: locationProvider.state) { _, state in handleLocationState(state) }
    .task { await locationCatalog.loadCountries(language: store.language) }
    .task(id: "\(selectedCountryCode)|\(store.language)|\(citySearch)") {
      guard country != nil, cityQueryIsValid else { return }
      if !citySearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
      }
      guard !Task.isCancelled else { return }
      await locationCatalog.loadCities(countryCode: selectedCountryCode, query: citySearch,
                                      language: store.language)
    }
    .onDisappear { stopLocationRequest() }
    .alert(text("Prayer times unavailable", "مواقيت الصلاة غير متاحة"),
           isPresented: Binding(get: { errorMessage != nil },
                                set: { if !$0 { errorMessage = nil } })) {
      Button(text("OK", "حسناً")) { errorMessage = nil }
    } message: { Text(errorMessage ?? "") }
    .accessibilityIdentifier("prayerLocationSheet")
  }

  private var choiceScreen: some View {
    VStack(spacing: 18) {
      HStack {
        Text(text("Prayer location", "موقع الصلاة"))
          .font(AppAppearance.font(size: 24, relativeTo: .title2, bold: true))
        Spacer(minLength: 12)
        Button(action: onFinish) {
          Image(systemName: "xmark")
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .accessibilityLabel(text("Close", "إغلاق"))
        .accessibilityIdentifier("location.close")
      }

      Button(action: requestLocation) {
        HStack(spacing: 10) {
          if locationRequestIsActive {
            ProgressView().tint(Color(.systemBackground))
          } else {
            Image(systemName: "location.fill")
          }
          Text(locationRequestIsActive
               ? text("Finding your location…", "جارٍ تحديد موقعك…")
               : text("Use current location", "استخدم موقعي الحالي"))
        }
        .frame(maxWidth: .infinity, minHeight: 32)
        .foregroundStyle(Color(.systemBackground))
      }
      .buttonStyle(.borderedProminent)
      .disabled(locationRequestIsActive)
      .accessibilityIdentifier("location.useDevice")

      HStack(spacing: 12) {
        Rectangle().frame(height: 1)
        Text(text("or", "أو"))
          .font(AppAppearance.font(size: 16, relativeTo: .subheadline, bold: true))
          .fixedSize()
        Rectangle().frame(height: 1)
      }
      .foregroundStyle(.secondary)
      .accessibilityHidden(true)

      VStack(spacing: 0) {
        NavigationLink(value: Route.countries) {
          HStack(spacing: 12) {
            if let flag = country?.flagEmoji {
              Text(flag)
                .font(.system(size: 24))
                .frame(width: 24)
                .accessibilityHidden(true)
            } else {
              Image(systemName: "globe")
                .frame(width: 24)
            }
            Text(text("Country", "الدولة"))
            Spacer(minLength: 8)
            Text(countryName)
              .foregroundStyle(.secondary)
              .lineLimit(1)
            Image(systemName: "chevron.forward")
              .font(.caption)
              .foregroundStyle(.secondary)
              .accessibilityHidden(true)
          }
          .frame(minHeight: 54)
          .contentShape(Rectangle())
        }
        .accessibilityIdentifier("location.country")

        Divider()

        NavigationLink(value: Route.cities) {
          HStack(spacing: 12) {
            Image(systemName: "building.2")
              .frame(width: 24)
            Text(text("Choose a city", "اختر مدينة"))
            Spacer(minLength: 8)
            Image(systemName: "chevron.forward")
              .font(.caption)
              .foregroundStyle(.secondary)
              .accessibilityHidden(true)
          }
          .frame(minHeight: 54)
          .contentShape(Rectangle())
        }
        .accessibilityIdentifier("location.chooseCity")
      }
      .padding(.horizontal, 16)
      .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 20)
    .padding(.top, 18)
    .fixedSize(horizontal: false, vertical: true)
    .background {
      GeometryReader { proxy in
        Color.clear.preference(key: LocationChoiceHeightKey.self, value: proxy.size.height)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(AppAppearance.background(accent))
    .toolbar(.hidden, for: .navigationBar)
  }

  private var cityScreen: some View {
    List {
      Section {
        if country == nil {
          NavigationLink(value: Route.countries) {
            Label(text("Choose a country first", "اختر دولة أولاً"), systemImage: "globe")
          }
        } else if citiesAreLoading && cities.isEmpty {
          ProgressView(text("Loading cities…", "جارٍ تحميل المدن…"))
            .frame(maxWidth: .infinity, minHeight: 72)
        } else if cityError != nil && cities.isEmpty {
          ContentUnavailableView(text("Cities are unavailable", "المدن غير متاحة"),
                                 systemImage: "wifi.slash",
                                 description: Text(text("Pull down to refresh.",
                                                        "اسحب للأسفل للتحديث.")))
        } else {
          ForEach(cities) { city in
            Button { select(city) } label: {
              VStack(alignment: .leading, spacing: 3) {
                Text(city.name(language: store.language)).foregroundStyle(.primary)
                if let region = city.region, !region.isEmpty {
                  Text(region).font(AppAppearance.font(size: 13)).foregroundStyle(.secondary)
                }
              }
              .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
              .contentShape(Rectangle())
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .accessibilityIdentifier("location.city.\(city.id)")
          }
          if cities.isEmpty {
            ContentUnavailableView(emptyCitiesMessage, systemImage: "magnifyingglass")
          }
          if cityQueryIsValid && locationCatalog.hasMoreCities(
            countryCode: selectedCountryCode, query: citySearch, language: store.language) {
            Button(text("Load more cities", "تحميل المزيد من المدن")) {
              Task { await locationCatalog.loadMoreCities(
                countryCode: selectedCountryCode, query: citySearch, language: store.language) }
            }
            .disabled(citiesAreLoading)
            .accessibilityIdentifier("location.loadMoreCities")
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(AppAppearance.background(accent))
    .listSectionSpacing(.compact)
    .refreshable { await locationCatalog.loadCities(
      countryCode: selectedCountryCode, query: citySearch,
      language: store.language, forceRefresh: true) }
    .scrollDismissesKeyboard(.interactively)
    .searchable(text: $citySearch, placement: .navigationBarDrawer(displayMode: .always),
                prompt: text("Search cities", "ابحث عن مدينة"))
    .navigationTitle(text("Choose a city", "اختر مدينة"))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.visible, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text(text("Choose a city", "اختر مدينة"))
          .font(AppAppearance.font(size: 21, relativeTo: .headline, bold: true))
      }
    }
  }

  private var countryScreen: some View {
    List {
      if locationCatalog.countriesLoading && locationCatalog.countries.isEmpty {
        ProgressView(text("Loading countries…", "جارٍ تحميل الدول…"))
          .frame(maxWidth: .infinity, minHeight: 72)
      } else if locationCatalog.countriesError != nil && locationCatalog.countries.isEmpty {
        ContentUnavailableView(text("Countries are unavailable", "الدول غير متاحة"),
                               systemImage: "globe",
                               description: Text(text("Pull down to refresh.",
                                                      "اسحب للأسفل للتحديث.")))
      } else {
        ForEach(countries) { item in
          Button {
            selectedCountryCode = item.code
            citySearch = ""
            countrySearch = ""
            if countrySearchIsPresented {
              countrySearchIsPresented = false
              Task {
                try? await Task.sleep(for: .milliseconds(250))
                path = []
                navigationID = UUID()
              }
            } else {
              path = []
              navigationID = UUID()
            }
          } label: {
            HStack(spacing: 12) {
              if let flag = item.flagEmoji {
                Text(flag)
                  .font(.system(size: 26))
                  .accessibilityHidden(true)
              }
              Text(item.name(language: store.language))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
              if selectedCountryCode == item.code {
                Image(systemName: "checkmark").fontWeight(.semibold)
                  .accessibilityLabel(text("Selected", "محدد"))
              }
            }
            .contentShape(Rectangle())
          }
          .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
          .accessibilityIdentifier("country.\(item.code)")
        }
        if countries.isEmpty {
          ContentUnavailableView(text("No matching countries", "لا توجد دول مطابقة"),
                                 systemImage: "magnifyingglass")
        }
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(AppAppearance.background(accent))
    .refreshable { await locationCatalog.loadCountries(
      language: store.language, forceRefresh: true) }
    .scrollDismissesKeyboard(.interactively)
    .searchable(text: $countrySearch, isPresented: $countrySearchIsPresented,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: text("Search countries", "ابحث عن دولة"))
    .navigationTitle(text("Country", "الدولة"))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.visible, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text(text("Country", "الدولة"))
          .font(AppAppearance.font(size: 21, relativeTo: .headline, bold: true))
      }
    }
  }

  private var emptyCitiesMessage: String {
    if !cityQueryIsValid {
      return text("Use 2–64 characters and up to 5 words.",
                  "استخدم حرفين إلى ٦٤ حرفاً، وبحد أقصى ٥ كلمات.")
    }
    if !citySearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return text("No matching cities", "لا توجد مدن مطابقة")
    }
    return text("No cities found", "لم يُعثر على مدن")
  }

  private func requestLocation() {
    locationRequestIsActive = true
    locationProvider.requestLocation()
  }

  private func stopLocationRequest() {
    locationRequestIsActive = false
    locationProvider.cancel()
  }

  private func handleLocationState(_ state: PrayerLocationProvider.State) {
    guard locationRequestIsActive else { return }
    switch state {
    case .idle, .requesting: break
    case .unavailable:
      locationRequestIsActive = false
      path = [.cities]
    case .located(let latitude, let longitude):
      locationRequestIsActive = false
      saveLocalLocation(latitude: latitude, longitude: longitude)
    }
  }

  private func saveLocalLocation(latitude: Double, longitude: Double) {
    var configuration = PrayerLocationProvider.localConfiguration(
      latitude: latitude, longitude: longitude, language: store.language)
    if let existing = prayerSchedule.configuration {
      configuration.madhab = existing.madhab
      configuration.ishaAdjustmentMinutes = existing.ishaAdjustmentMinutes
    }
    save(configuration)
  }

  private func select(_ city: PrayerCity) {
    stopLocationRequest()
    let existing = prayerSchedule.configuration
    let configuration = PrayerScheduleConfiguration(
      city: city,
      madhab: existing?.madhab ?? .shafi,
      ishaAdjustmentMinutes: existing?.ishaAdjustmentMinutes ?? 0,
      language: store.language)
    save(configuration)
  }

  private func save(_ configuration: PrayerScheduleConfiguration) {
    do {
      try prayerSchedule.save(configuration)
      onFinish()
    } catch {
      errorMessage = text("Unable to save this location.", "تعذر حفظ هذا الموقع.")
    }
  }

  private func restoreCountrySelection() {
    guard !restoredCountry else { return }
    restoredCountry = true
    guard let configuration = prayerSchedule.configuration else { return }
    selectedCountryCode = configuration.countryCode
      ?? PrayerCountryCatalog.countryCode(for: configuration.locationName)
      ?? PrayerCountryCatalog.defaultCountryCode()
  }
}
