import SwiftUI

struct PrayerLocationSheet: View {
  @EnvironmentObject private var store: AzkarStore
  @EnvironmentObject private var prayerSchedule: PrayerScheduleStore
  @EnvironmentObject private var locationCatalog: LocationCatalogStore
  @AppStorage("accent") private var accent = "brown"
  @StateObject private var locationProvider = PrayerLocationProvider()
  @State private var showingCities = false
  @State private var showingCountrySelection = false
  @State private var search = ""
  @State private var selectedCountryCode = PrayerCountryCatalog.defaultCountryCode()
  @State private var locationRequestIsActive = false
  @State private var errorMessage: String?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  let onFinish: () -> Void
  let onOpenSettings: () -> Void

  private var arabic: Bool { store.language == "ar" }

  private func text(_ english: String, _ arabic: String) -> String {
    self.arabic ? arabic : english
  }

  private var selectedCountryIsAvailable: Bool {
    !selectedCountryCode.isEmpty
      && locationCatalog.countries.contains { $0.code == selectedCountryCode }
  }

  private var citySearchIsValid: Bool {
    LocationCatalogStore.normalizedQuery(search) != nil
  }

  private var cityRequestKey: String { "\(selectedCountryCode)|\(store.language)|\(search)" }

  private var filteredCities: [PrayerCity] {
    guard selectedCountryIsAvailable, citySearchIsValid else { return [] }
    return locationCatalog.cities(for: selectedCountryCode, query: search, language: store.language)
  }

  private var cityError: String? {
    locationCatalog.cityError(countryCode: selectedCountryCode, query: search, language: store.language)
  }

  private var citiesAreLoading: Bool {
    locationCatalog.isLoadingCities(countryCode: selectedCountryCode, query: search, language: store.language)
  }

  private var selectedCountryName: String {
    guard selectedCountryIsAvailable else {
      return text("Choose a country", "اختر دولة")
    }
    return locationCatalog.countries.first { $0.code == selectedCountryCode }?
      .name(language: store.language)
      ?? selectedCountryCode
  }

  private var countryIsLoading: Bool {
    selectedCountryIsAvailable
      && citiesAreLoading
      && filteredCities.isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack {
          Spacer()
          Button(action: onFinish) {
            Image(systemName: "xmark")
          }
          .buttonStyle(.bordered)
          .buttonBorderShape(.circle)
          .accessibilityLabel(text("Close", "إغلاق"))
          .accessibilityIdentifier("location.close")
        }
        if showingCities {
          cityPicker
        } else {
          introduction
          actions
          settingsNote
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 20)
      .frame(maxWidth: .infinity, alignment: .leading)
      .fixedSize(horizontal: false, vertical: true)
      .sheetContentHeight()
    }
    .scrollDismissesKeyboard(.interactively)
    .background(Color(.systemBackground))
    .font(AppAppearance.font(size: 17))
    .tint(AppAppearance.accent(accent))
    .environment(\.layoutDirection, arabic ? .rightToLeft : .leftToRight)
    .contentSizedSheet(maximumHeightFraction: 0.85, minimumHeight: 280)
    .sheet(isPresented: $showingCountrySelection) {
      CountrySelectionSheet(
        selectedCountryCode: selectedCountryCode,
        onSelect: selectCountry)
      .presentationDetents([.large])
      .presentationDragIndicator(.visible)
    }
    .onAppear(perform: restoreCountrySelection)
    .onChange(of: locationProvider.state) { _, state in
      handleLocationState(state)
    }
    .task {
      await locationCatalog.loadCountries(language: store.language)
    }
    .task(id: cityRequestKey) {
      guard selectedCountryIsAvailable, citySearchIsValid else { return }
      if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
      }
      guard !Task.isCancelled else { return }
      await locationCatalog.loadCities(countryCode: selectedCountryCode, query: search, language: store.language)
    }
    .onDisappear {
      locationRequestIsActive = false
      locationProvider.cancel()
    }
    .alert(
      text("Prayer times unavailable", "مواقيت الصلاة غير متاحة"),
      isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
      )
    ) {
      Button(text("OK", "حسناً")) { errorMessage = nil }
    } message: {
      Text(errorMessage ?? "")
    }
    .accessibilityIdentifier("prayerLocationSheet")
  }

  private var introduction: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(text("Set your prayer location", "حدد موقع الصلاة"))
        .font(AppAppearance.font(size: 27, relativeTo: .title2, bold: true))
      Text(text(
        "Prayer times use your city or device location. Your coordinates are used on this device and are not uploaded.",
        "تستخدم مواقيت الصلاة مدينتك أو موقع جهازك. تُستخدم إحداثياتك على هذا الجهاز ولا تُرفع إلى أي جهة."))
        .font(AppAppearance.font(size: 15))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  @ViewBuilder
  private var actions: some View {
    VStack(spacing: 10) {
      Button(action: requestLocation) {
        Label {
          Text(locationRequestIsActive
            ? text("Finding your location…", "جارٍ تحديد موقعك…")
            : text("Use my location", "استخدم موقعي"))
        } icon: {
          if locationRequestIsActive {
            ProgressView()
              .controlSize(.small)
          } else {
            Image(systemName: "location.fill")
          }
        }
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .accessibilityIdentifier("location.useDevice")
      .disabled(locationRequestIsActive)

      Button {
        stopLocationRequest()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showingCities = true }
      } label: {
        Label(text("Choose a city", "اختر مدينة"), systemImage: "building.2")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .controlSize(.large)
      .accessibilityIdentifier("location.chooseCity")
    }
  }

  private var settingsNote: some View {
    Text(text(
      "You can change your city anytime in Settings → Prayer times.",
      "يمكنك تغيير مدينتك في أي وقت من الإعدادات ← مواقيت الصلاة."))
      .font(AppAppearance.font(size: 13))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 4)
  }

  private var cityPicker: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
        Text(text("Choose your city", "اختر مدينتك"))
          .font(AppAppearance.font(size: 25, relativeTo: .title2, bold: true))
        Spacer(minLength: 0)
        Button {
          stopLocationRequest()
          withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            showingCities = false
          }
        } label: {
          Label(text("Back", "رجوع"), systemImage: "chevron.backward")
        }
        .buttonStyle(.bordered)
        .foregroundStyle(AppAppearance.accent(accent))
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityIdentifier("location.back")
      }

      Button { showingCountrySelection = true } label: {
        HStack(spacing: 12) {
          Label(text("Country", "الدولة"), systemImage: "globe")
          Spacer(minLength: 8)
          Text(selectedCountryName)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Image(systemName: "chevron.forward")
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.bordered)
      .accessibilityIdentifier("location.country")

      TextField(text("Search cities", "ابحث عن مدينة"), text: $search)
        .textFieldStyle(.roundedBorder)
        .accessibilityIdentifier("location.search")
      Text(text("Online city searches send search terms, never your GPS coordinates.",
                "يرسل البحث عبر الإنترنت أسماء المدن فقط، ولا يرسل إحداثيات موقعك."))
        .font(AppAppearance.font(size: 12))
        .foregroundStyle(.secondary)

      Text(text(
        "You can change your city anytime in Settings → Prayer times.",
        "يمكنك تغيير مدينتك في أي وقت من الإعدادات ← مواقيت الصلاة."))
        .font(AppAppearance.font(size: 13))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if countryIsLoading {
        ProgressView(text("Loading cities…", "جارٍ تحميل المدن…"))
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.vertical, 14)
      } else if cityError != nil,
        filteredCities.isEmpty
      {
        VStack(spacing: 8) {
          Text(text(
            "Cities are unavailable right now. Try again.",
            "المدن غير متاحة حالياً. حاول مرة أخرى."))
            .font(AppAppearance.font(size: 14))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
          Button(text("Retry", "إعادة المحاولة")) {
            Task {
              await locationCatalog.loadCities(
                countryCode: selectedCountryCode, query: search, language: store.language,
                forceRefresh: true)
            }
          }
          .buttonStyle(.bordered)
          .accessibilityIdentifier("location.retryCities")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
      } else {
        if cityError != nil {
          cityCatalogRetryRow
        }

        LazyVStack(spacing: 8) {
          ForEach(filteredCities) { city in
            Button {
              select(city)
            } label: {
              HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                  .foregroundStyle(AppAppearance.accent(accent))
                  .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                  Text(city.name(language: store.language))
                  if let region = city.region, !region.isEmpty {
                    Text(region).font(AppAppearance.font(size: 12)).foregroundStyle(.secondary)
                  }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .accessibilityHidden(true)
              }
              .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
              .contentShape(Rectangle())
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("location.city.\(city.id)")
          }
        }

        loadMoreCities

        if filteredCities.isEmpty {
          Text(emptyCitiesMessage)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 14)
        }
      }

      Divider()

      Button {
        stopLocationRequest()
        onOpenSettings()
      } label: {
        Label(
          text("Other city / Set manually", "مدينة أخرى / إدخال يدوي"),
          systemImage: "slider.horizontal.3"
        )
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
      }
      .buttonStyle(.bordered)
      .foregroundStyle(AppAppearance.accent(accent))
      .accessibilityIdentifier("location.openSettings")
    }
  }

  private var cityCatalogRetryRow: some View {
    HStack(spacing: 10) {
      Text(text(
        "Some cities may be unavailable. Try again to refresh.",
        "قد لا تتوفر بعض المدن. حاول مرة أخرى للتحديث."))
        .font(AppAppearance.font(size: 13))
        .foregroundStyle(.secondary)
      Spacer(minLength: 8)
      Button(text("Retry", "إعادة المحاولة")) {
        Task {
          await locationCatalog.loadCities(
            countryCode: selectedCountryCode, query: search, language: store.language,
            forceRefresh: true)
        }
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      .accessibilityIdentifier("location.retryCities")
    }
  }

  @ViewBuilder
  private var loadMoreCities: some View {
    if citySearchIsValid && locationCatalog.hasMoreCities(
      countryCode: selectedCountryCode, query: search, language: store.language)
    {
      Button(text("Load more cities", "تحميل المزيد من المدن")) {
        Task {
          await locationCatalog.loadMoreCities(
            countryCode: selectedCountryCode, query: search, language: store.language)
        }
      }
      .disabled(citiesAreLoading)
      .frame(minHeight: 44)
      .accessibilityIdentifier("location.loadMoreCities")
    }
  }

  private var emptyCitiesMessage: String {
    let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
    if !citySearchIsValid {
      return text("Search with 2–64 characters and up to 5 words.",
                  "ابحث باستخدام حرفين إلى ٦٤ حرفاً، وبحد أقصى ٥ كلمات.")
    }
    if !query.isEmpty {
      return text("No matching cities", "لا توجد مدن مطابقة")
    }
    if selectedCountryCode.isEmpty {
      return text("Choose a country to browse cities.", "اختر دولة لتصفح المدن.")
    }
    let countryName = selectedCountryName
    return text(
      "No cities for \(countryName). Set a city manually in Settings.",
      "لا توجد مدن في \(countryName). أدخل مدينة يدوياً من الإعدادات.")
  }

  private func selectCountry(_ country: PrayerCountry) {
    selectedCountryCode = country.code
    search = ""
    showingCountrySelection = false
  }

  private func requestLocation() {
    search = ""
    showingCities = false
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
    case .idle, .requesting:
      break
    case .unavailable:
      locationRequestIsActive = false
      withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showingCities = true }
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
    guard let configuration = prayerSchedule.configuration else { return }
    selectedCountryCode = configuration.countryCode
      ?? PrayerCountryCatalog.countryCode(for: configuration.locationName)
      ?? PrayerCountryCatalog.defaultCountryCode()
  }
}
