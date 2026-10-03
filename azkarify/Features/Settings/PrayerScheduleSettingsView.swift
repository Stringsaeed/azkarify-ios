import SwiftUI

private struct AppliedLocationMetadata: Equatable {
  let countryCode: String?
  let cityID: String?
  let localizedNames: [String: String]?
  let usesDeviceLocation: Bool
  let locationName: String
  let latitude: Double
  let longitude: Double
  let timeZoneIdentifier: String
  let method: PrayerCalculationMethod

  func matches(
    locationName: String,
    latitude: Double,
    longitude: Double,
    timeZoneIdentifier: String,
    method: PrayerCalculationMethod
  ) -> Bool {
    self.locationName == locationName
      && self.latitude == latitude
      && self.longitude == longitude
      && self.timeZoneIdentifier == timeZoneIdentifier
      && self.method == method
  }
}

struct PrayerScheduleSettingsView: View {
  @EnvironmentObject private var store: AzkarStore
  @EnvironmentObject private var locationCatalog: LocationCatalogStore
  @EnvironmentObject private var prayerSchedule: PrayerScheduleStore
  @Environment(\.dismiss) private var dismiss
  @AppStorage("accent") private var accent = "brown"
  @State private var locationName = ""
  @State private var latitude = ""
  @State private var longitude = ""
  @State private var timeZoneIdentifier = ""
  @State private var method: PrayerCalculationMethod = .muslimWorldLeague
  @State private var madhab: PrayerMadhab = .shafi
  @State private var ishaAdjustmentMinutes = 0
  @State private var selectedCountryCode = PrayerCountryCatalog.defaultCountryCode()
  @State private var appliedLocationMetadata: AppliedLocationMetadata?
  @State private var errorMessage: String?
  @State private var loadedConfiguration = false

  private var arabic: Bool { store.language == "ar" }

  private func text(_ english: String, _ arabic: String) -> String {
    self.arabic ? arabic : english
  }

  private var draft: PrayerScheduleConfiguration? {
    guard let latitude = coordinate(latitude), let longitude = coordinate(longitude) else {
      return nil
    }
    let locationName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
    let timeZoneIdentifier = timeZoneIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
    let metadata = appliedLocationMetadata?.matches(
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      timeZoneIdentifier: timeZoneIdentifier,
      method: method) == true ? appliedLocationMetadata : nil
    let configuration = PrayerScheduleConfiguration(
      locationName: locationName,
      latitude: latitude, longitude: longitude,
      timeZoneIdentifier: timeZoneIdentifier,
      method: method,
      madhab: madhab,
      ishaAdjustmentMinutes: ishaAdjustmentMinutes,
      countryCode: metadata?.countryCode,
      cityID: metadata?.cityID,
      localizedLocationNames: metadata?.localizedNames,
      usesDeviceLocation: metadata?.usesDeviceLocation ?? false)
    return configuration.isValid ? configuration : nil
  }

  var body: some View {
    Form {
      Section {
        NavigationLink {
          PrayerCityPicker(language: store.language, selectedCountryCode: $selectedCountryCode) { city in
            locationName = city.name(language: store.language)
            latitude = String(city.latitude)
            longitude = String(city.longitude)
            timeZoneIdentifier = city.timeZone
            method = city.method
            appliedLocationMetadata = AppliedLocationMetadata(
              countryCode: city.countryCode,
              cityID: city.id,
              localizedNames: city.localizedNames,
              usesDeviceLocation: false,
              locationName: city.name(language: store.language),
              latitude: city.latitude,
              longitude: city.longitude,
              timeZoneIdentifier: city.timeZone,
              method: city.method)
          }
        } label: {
          Label(text("Choose a city", "اختر مدينة"), systemImage: "map")
        }
        TextField(text("Location name", "اسم الموقع"), text: $locationName)
          .accessibilityIdentifier("prayer.locationName")
        coordinateField(text("Latitude", "خط العرض"), value: $latitude)
          .accessibilityIdentifier("prayer.latitude")
        coordinateField(text("Longitude", "خط الطول"), value: $longitude)
          .accessibilityIdentifier("prayer.longitude")
        NavigationLink {
          PrayerTimeZonePicker(selection: $timeZoneIdentifier, language: store.language)
        } label: {
          LabeledContent(text("Time zone", "المنطقة الزمنية")) {
            Text(timeZoneIdentifier.isEmpty ? text("Choose", "اختر") : timeZoneIdentifier)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.trailing)
          }
        }
        .accessibilityIdentifier("prayer.timeZone")
      } header: {
        Text(text("Location", "الموقع"))
      } footer: {
        VStack(alignment: .leading, spacing: 8) {
          Text(text(
            "Choose a city or enter your coordinates and time zone. City coordinates represent the city center. Your coordinates are used on this device and are not uploaded.",
            "اختر مدينة أو أدخل إحداثياتك ومنطقتك الزمنية. إحداثيات المدن تشير إلى وسط المدينة. تُستخدم إحداثياتك على هذا الجهاز ولا تُرفع إلى أي جهة."))
          Text(text(
            "You can change your city anytime in Settings → Prayer times.",
            "يمكنك تغيير مدينتك في أي وقت من الإعدادات ← مواقيت الصلاة."))
        }
      }

      Section {
        Picker(text("Calculation method", "طريقة الحساب"), selection: $method) {
          ForEach(PrayerCalculationMethod.allCases) { method in
            Text(method.title(language: store.language)).tag(method)
          }
        }
        .accessibilityIdentifier("prayer.method")
        Picker(text("Asr calculation", "حساب العصر"), selection: $madhab) {
          ForEach(PrayerMadhab.allCases) { madhab in
            Text(madhab.title(language: store.language)).tag(madhab)
          }
        }
        .accessibilityIdentifier("prayer.madhab")
        Stepper(value: $ishaAdjustmentMinutes, in: -60...60, step: 1) {
          Text(text(
            "Isha adjustment: \(ishaAdjustmentMinutes) min",
            "تعديل العشاء: \(ishaAdjustmentMinutes) دقيقة"))
        }
      } header: {
        Text(text("Calculation", "الحساب"))
      } footer: {
        VStack(alignment: .leading, spacing: 8) {
          Text(text(
            "Times mark the start of each prayer. Follow your local mosque for iqama. Fajr and Isha at high latitudes use Adhan's recommended night rule.",
            "المواقيت هي بداية وقت كل صلاة. اتبع مسجدك المحلي لمعرفة موعد الإقامة. يُستخدم تقدير الليل الموصى به في مكتبة Adhan للفجر والعشاء في خطوط العرض العليا."))
          if method == .ummAlQura {
            Text(text(
              "For Umm al-Qura in Ramadan, set the Isha adjustment to +30 minutes. Reset it after Ramadan.",
              "لطريقة أم القرى في رمضان، اضبط تعديل العشاء على +٣٠ دقيقة، ثم أعده إلى الصفر بعد رمضان."))
          }
        }
      }

      Section {
        Button(text("Save prayer times", "حفظ مواقيت الصلاة")) {
          guard let draft else { return }
          do {
            try prayerSchedule.save(draft)
            dismiss()
          } catch {
            errorMessage = text("Unable to save this location.", "تعذر حفظ هذا الموقع.")
          }
        }
        .disabled(draft == nil)
        .accessibilityIdentifier("prayer.save")
        if prayerSchedule.configuration != nil {
          Button(text("Remove saved location", "حذف الموقع المحفوظ"), role: .destructive) {
            prayerSchedule.clear()
            dismiss()
          }
        }
      }
    }
    .scrollContentBackground(.hidden)
    .background(AppAppearance.background(accent))
    .font(AppAppearance.font(size: 17))
    .tint(AppAppearance.accent(accent))
    .appNavigationTitle(text("Prayer times", "مواقيت الصلاة"), language: store.language)
    .onAppear {
      guard !loadedConfiguration else { return }
      loadedConfiguration = true
      guard let saved = prayerSchedule.configuration else { return }
      selectedCountryCode = saved.countryCode
        ?? PrayerCountryCatalog.countryCode(for: saved.locationName)
        ?? ""
      let savedLocationName = saved.displayLocationName(language: store.language)
      if saved.countryCode != nil || saved.cityID != nil || saved.usesDeviceLocation {
        appliedLocationMetadata = AppliedLocationMetadata(
          countryCode: saved.countryCode,
          cityID: saved.cityID,
          localizedNames: saved.localizedLocationNames,
          usesDeviceLocation: saved.usesDeviceLocation,
          locationName: savedLocationName,
          latitude: saved.latitude,
          longitude: saved.longitude,
          timeZoneIdentifier: saved.timeZoneIdentifier,
          method: saved.method)
      }
      locationName = savedLocationName
      latitude = String(saved.latitude)
      longitude = String(saved.longitude)
      timeZoneIdentifier = saved.timeZoneIdentifier
      method = saved.method
      madhab = saved.madhab
      ishaAdjustmentMinutes = saved.ishaAdjustmentMinutes
    }
    .alert(text("Prayer times unavailable", "مواقيت الصلاة غير متاحة"), isPresented: Binding(
      get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
    )) {
      Button(text("OK", "حسناً")) { errorMessage = nil }
    } message: {
      Text(errorMessage ?? "")
    }
  }

  private func coordinateField(_ title: String, value: Binding<String>) -> some View {
    HStack {
      Text(title)
      TextField("0.0000", text: value)
        .keyboardType(.numbersAndPunctuation)
        .multilineTextAlignment(.trailing)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .environment(\.layoutDirection, .leftToRight)
    }
  }

  private func coordinate(_ value: String) -> Double? {
    let input = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalized = input.map { character -> String in
      if let digit = character.wholeNumberValue { return String(digit) }
      if character == "٫" { return "." }
      if character == "−" { return "-" }
      return String(character)
    }.joined()
    return Double(normalized)
  }
}

private struct PrayerCityPicker: View {
  let language: String
  @Binding var selectedCountryCode: String
  let select: (PrayerCity) -> Void
  @EnvironmentObject private var locationCatalog: LocationCatalogStore
  @Environment(\.dismiss) private var dismiss
  @State private var search = ""
  @State private var showingCountrySelection = false

  private var arabic: Bool { language.hasPrefix("ar") }

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

  private var cityRequestKey: String { "\(selectedCountryCode)|\(language)|\(search)" }

  private var filteredCities: [PrayerCity] {
    guard selectedCountryIsAvailable, citySearchIsValid else { return [] }
    return locationCatalog.cities(for: selectedCountryCode, query: search, language: language)
  }

  private var cityError: String? {
    locationCatalog.cityError(countryCode: selectedCountryCode, query: search, language: language)
  }

  private var citiesAreLoading: Bool {
    locationCatalog.isLoadingCities(countryCode: selectedCountryCode, query: search, language: language)
  }

  private var selectedCountryName: String {
    guard selectedCountryIsAvailable,
      let country = locationCatalog.countries.first(where: { $0.code == selectedCountryCode })
    else {
      return text("Choose a country", "اختر دولة")
    }
    return country.name(language: language)
  }

  var body: some View {
    List {
      Section {
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
          .frame(minHeight: 44)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("prayer.country")
        .onChange(of: selectedCountryCode) { _, _ in
          search = ""
        }
      }

      Section {
        Text(text("Online city searches send search terms, never your GPS coordinates.",
                  "يرسل البحث عبر الإنترنت أسماء المدن فقط، ولا يرسل إحداثيات موقعك."))
          .font(AppAppearance.font(size: 12))
          .foregroundStyle(.secondary)
        if !selectedCountryIsAvailable {
          Text(text(
            "Choose a country to browse cities.",
            "اختر دولة لتصفح المدن."))
            .foregroundStyle(.secondary)
        } else if citiesAreLoading,
          filteredCities.isEmpty
        {
          ProgressView(text("Loading cities…", "جارٍ تحميل المدن…"))
        } else if let _ = cityError,
          filteredCities.isEmpty
        {
          VStack(alignment: .leading, spacing: 8) {
            Text(text(
              "Cities are unavailable right now. Try again.",
              "المدن غير متاحة حالياً. حاول مرة أخرى."))
              .foregroundStyle(.secondary)
            Button(text("Retry", "إعادة المحاولة")) {
              Task {
                await locationCatalog.loadCities(
                  countryCode: selectedCountryCode, query: search, language: language,
                  forceRefresh: true)
              }
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("prayer.retryCities")
          }
        } else {
          if cityError != nil {
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
                    countryCode: selectedCountryCode, query: search, language: language,
                    forceRefresh: true)
                }
              }
              .buttonStyle(.bordered)
              .controlSize(.small)
              .accessibilityIdentifier("prayer.retryCities")
            }
          }

          ForEach(filteredCities) { city in
            Button {
              select(city)
              dismiss()
            } label: {
              HStack {
                VStack(alignment: .leading, spacing: 3) {
                  Text(city.name(language: language))
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
              .frame(minHeight: 44)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("prayer.city.\(city.id)")
          }
        }

        loadMoreCities

        if selectedCountryIsAvailable && filteredCities.isEmpty
          && !citiesAreLoading
          && cityError == nil
        {
          Text(emptyMessage)
            .foregroundStyle(.secondary)
        }
      }
    }
    .font(AppAppearance.font(size: 17))
    .searchable(text: $search, prompt: language == "ar" ? "ابحث عن مدينة" : "Search cities")
    .appNavigationTitle(language == "ar" ? "اختر مدينة" : "Choose a city", language: language)
    .sheet(isPresented: $showingCountrySelection) {
      CountrySelectionSheet(
        selectedCountryCode: selectedCountryCode,
        onSelect: { country in
          selectedCountryCode = country.code
          search = ""
          showingCountrySelection = false
        })
      .presentationDetents([.large])
      .presentationDragIndicator(.visible)
    }
    .task(id: cityRequestKey) {
      guard selectedCountryIsAvailable, citySearchIsValid else { return }
      if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
      }
      guard !Task.isCancelled else { return }
      await locationCatalog.loadCities(countryCode: selectedCountryCode, query: search, language: language)
    }
    .task {
      await locationCatalog.loadCountries(language: language)
    }
  }

  @ViewBuilder
  private var loadMoreCities: some View {
    if citySearchIsValid && locationCatalog.hasMoreCities(
      countryCode: selectedCountryCode, query: search, language: language)
    {
      Button(text("Load more cities", "تحميل المزيد من المدن")) {
        Task {
          await locationCatalog.loadMoreCities(
            countryCode: selectedCountryCode, query: search, language: language)
        }
      }
      .disabled(citiesAreLoading)
      .frame(minHeight: 44)
      .accessibilityIdentifier("prayer.loadMoreCities")
    }
  }

  private var emptyMessage: String {
    let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
    if !citySearchIsValid {
      return text("Search with 2–64 characters and up to 5 words.",
                  "ابحث باستخدام حرفين إلى ٦٤ حرفاً، وبحد أقصى ٥ كلمات.")
    }
    if !query.isEmpty {
      return language == "ar" ? "لا توجد مدن مطابقة" : "No matching cities"
    }
    if !selectedCountryIsAvailable {
      return language == "ar"
        ? "اختر دولة لتصفح المدن."
        : "Choose a country to browse cities."
    }
    let countryName = selectedCountryName
    return language == "ar"
      ? "لا توجد مدن في \(countryName). أدخل موقعاً يدوياً أدناه."
      : "No cities for \(countryName). Enter a location manually below."
  }
}

private struct PrayerTimeZonePicker: View {
  @Binding var selection: String
  let language: String
  @Environment(\.dismiss) private var dismiss
  @State private var search = ""

  var body: some View {
    List(TimeZone.knownTimeZoneIdentifiers.filter {
      search.isEmpty || $0.localizedCaseInsensitiveContains(search)
    }, id: \.self) { identifier in
      Button {
        selection = identifier
        dismiss()
      } label: {
        HStack {
          Text(identifier)
          Spacer()
          if selection == identifier { Image(systemName: "checkmark") }
        }
      }
    }
    .font(AppAppearance.font(size: 17))
    .searchable(text: $search, prompt: language == "ar" ? "ابحث عن منطقة زمنية" : "Search time zones")
    .appNavigationTitle(language == "ar" ? "المنطقة الزمنية" : "Time zone", language: language)
  }
}
