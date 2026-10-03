import Adhan
import Combine
import Foundation

enum DailyPrayer: String, Codable, CaseIterable, Identifiable {
  case fajr, dhuhr, asr, maghrib, isha

  var id: String { rawValue }

  func title(language: String) -> String {
    switch self {
    case .fajr: return language == "ar" ? "الفجر" : "Fajr"
    case .dhuhr: return language == "ar" ? "الظهر" : "Dhuhr"
    case .asr: return language == "ar" ? "العصر" : "Asr"
    case .maghrib: return language == "ar" ? "المغرب" : "Maghrib"
    case .isha: return language == "ar" ? "العشاء" : "Isha"
    }
  }

  fileprivate var adhanPrayer: Prayer {
    switch self {
    case .fajr: return .fajr
    case .dhuhr: return .dhuhr
    case .asr: return .asr
    case .maghrib: return .maghrib
    case .isha: return .isha
    }
  }
}

enum PrayerCalculationMethod: String, Codable, CaseIterable, Identifiable {
  case muslimWorldLeague, egyptian, karachi, ummAlQura, dubai, moonsightingCommittee
  case northAmerica, kuwait, qatar, singapore, tehran, turkey

  var id: String { rawValue }

  func title(language: String) -> String {
    let arabic = language == "ar"
    switch self {
    case .muslimWorldLeague: return arabic ? "رابطة العالم الإسلامي" : "Muslim World League"
    case .egyptian: return arabic ? "الهيئة المصرية العامة للمساحة" : "Egyptian General Authority of Survey"
    case .karachi: return arabic ? "جامعة العلوم الإسلامية، كراتشي" : "University of Islamic Sciences, Karachi"
    case .ummAlQura: return arabic ? "جامعة أم القرى، مكة" : "Umm al-Qura, Makkah"
    case .dubai: return arabic ? "دبي، الإمارات العربية المتحدة" : "Dubai, UAE"
    case .moonsightingCommittee: return arabic ? "لجنة رؤية الهلال" : "Moonsighting Committee"
    case .northAmerica: return arabic ? "أمريكا الشمالية، ISNA" : "North America, ISNA"
    case .kuwait: return arabic ? "الكويت" : "Kuwait"
    case .qatar: return arabic ? "قطر" : "Qatar"
    case .singapore: return arabic ? "سنغافورة" : "Singapore"
    case .tehran: return arabic ? "معهد الجيوفيزياء، طهران" : "Institute of Geophysics, Tehran"
    case .turkey: return arabic ? "تركيا، تقريب لطريقة ديانت" : "Turkey, Diyanet approximation"
    }
  }

  fileprivate var parameters: CalculationParameters {
    switch self {
    case .muslimWorldLeague: return CalculationMethod.muslimWorldLeague.params
    case .egyptian: return CalculationMethod.egyptian.params
    case .karachi: return CalculationMethod.karachi.params
    case .ummAlQura: return CalculationMethod.ummAlQura.params
    case .dubai: return CalculationMethod.dubai.params
    case .moonsightingCommittee: return CalculationMethod.moonsightingCommittee.params
    case .northAmerica: return CalculationMethod.northAmerica.params
    case .kuwait: return CalculationMethod.kuwait.params
    case .qatar: return CalculationMethod.qatar.params
    case .singapore: return CalculationMethod.singapore.params
    case .tehran: return CalculationMethod.tehran.params
    case .turkey: return CalculationMethod.turkey.params
    }
  }
}

enum PrayerMadhab: String, Codable, CaseIterable, Identifiable {
  case shafi, hanafi
  var id: String { rawValue }

  func title(language: String) -> String {
    if self == .hanafi { return language == "ar" ? "الحنفي، العصر المتأخر" : "Hanafi, later Asr" }
    return language == "ar" ? "الشافعي والمالكي والحنبلي" : "Shafi, Maliki, Hanbali"
  }
}

struct PrayerScheduleConfiguration: Codable, Equatable {
  var locationName: String
  var latitude: Double
  var longitude: Double
  var timeZoneIdentifier: String
  var method: PrayerCalculationMethod
  var madhab: PrayerMadhab
  var ishaAdjustmentMinutes: Int = 0
  var countryCode: String? = nil
  var cityID: String? = nil
  /// The chosen city's name in each app language, keyed by "en" and "ar".
  var localizedLocationNames: [String: String]? = nil
  var usesDeviceLocation = false

  /// The location label in the given language. Saved city and device labels
  /// follow the app language; a name the user typed is shown as typed.
  func displayLocationName(language: String) -> String {
    let arabic = language.hasPrefix("ar")
    if usesDeviceLocation { return arabic ? "الموقع الحالي" : "Current location" }
    guard let names = localizedLocationNames, names.values.contains(locationName) else {
      return locationName
    }
    return names[arabic ? "ar" : "en"] ?? locationName
  }

  var isValid: Bool {
    !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && latitude.isFinite && (-90...90).contains(latitude)
      && longitude.isFinite && (-180...180).contains(longitude)
      && TimeZone(identifier: timeZoneIdentifier) != nil
      && (-60...60).contains(ishaAdjustmentMinutes)
  }

  var calendar: Calendar? {
    guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else { return nil }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar
  }
}

extension PrayerScheduleConfiguration {
  static let deviceLocationNames: Set<String> = ["Current location", "الموقع الحالي"]

  init(
    city: PrayerCity,
    madhab: PrayerMadhab,
    ishaAdjustmentMinutes: Int,
    language: String
  ) {
    self.init(
      locationName: city.name(language: language),
      latitude: city.latitude,
      longitude: city.longitude,
      timeZoneIdentifier: city.timeZone,
      method: city.method,
      madhab: madhab,
      ishaAdjustmentMinutes: ishaAdjustmentMinutes,
      countryCode: city.countryCode,
      cityID: city.id,
      localizedLocationNames: city.localizedNames)
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    locationName = try container.decode(String.self, forKey: .locationName)
    latitude = try container.decode(Double.self, forKey: .latitude)
    longitude = try container.decode(Double.self, forKey: .longitude)
    timeZoneIdentifier = try container.decode(String.self, forKey: .timeZoneIdentifier)
    method = try container.decode(PrayerCalculationMethod.self, forKey: .method)
    madhab = try container.decode(PrayerMadhab.self, forKey: .madhab)
    ishaAdjustmentMinutes =
      try container.decodeIfPresent(Int.self, forKey: .ishaAdjustmentMinutes) ?? 0
    countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
    cityID = try container.decodeIfPresent(String.self, forKey: .cityID)
    localizedLocationNames =
      try container.decodeIfPresent([String: String].self, forKey: .localizedLocationNames)
    // Older configurations stored only the label, in the language that was
    // active when it was saved.
    usesDeviceLocation =
      try container.decodeIfPresent(Bool.self, forKey: .usesDeviceLocation)
      ?? (cityID == nil && Self.deviceLocationNames.contains(locationName))
    if localizedLocationNames == nil, let cityID,
      let city = PrayerCity.cities.first(where: { $0.id == cityID })
    {
      localizedLocationNames = city.localizedNames
    }
  }
}

struct ScheduledPrayer: Identifiable, Equatable {
  let prayer: DailyPrayer
  let time: Date
  var id: DailyPrayer { prayer }
}

enum PrayerScheduleError: Error {
  case invalidConfiguration
}

@MainActor
final class PrayerScheduleStore: ObservableObject {
  @Published private(set) var configuration: PrayerScheduleConfiguration?
  @Published private(set) var schedule: [ScheduledPrayer] = []
  private let defaults: UserDefaults
  private static let configurationKey = "prayerSchedule.configuration.v1"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: Self.configurationKey),
      let saved = try? JSONDecoder().decode(PrayerScheduleConfiguration.self, from: data),
      saved.isValid
    {
      configuration = saved
    }
    refresh()
  }

  func save(_ configuration: PrayerScheduleConfiguration) throws {
    guard configuration.isValid else { throw PrayerScheduleError.invalidConfiguration }
    let data = try JSONEncoder().encode(configuration)
    defaults.set(data, forKey: Self.configurationKey)
    self.configuration = configuration
    refresh()
  }

  func clear() {
    defaults.removeObject(forKey: Self.configurationKey)
    configuration = nil
    schedule = []
  }

  func refresh(on date: Date = Date()) {
    schedule = prayers(on: date)
  }

  func prayers(on date: Date) -> [ScheduledPrayer] {
    guard let configuration, configuration.isValid, let calendar = configuration.calendar else {
      return []
    }
    let coordinates = Coordinates(
      latitude: configuration.latitude, longitude: configuration.longitude)
    var parameters = configuration.method.parameters
    parameters.madhab = configuration.madhab == .hanafi ? .hanafi : .shafi
    parameters.highLatitudeRule = HighLatitudeRule.recommended(for: coordinates)
    parameters.adjustments.isha = configuration.ishaAdjustmentMinutes
    let day = calendar.dateComponents([.year, .month, .day], from: date)
    guard let times = PrayerTimes(
      coordinates: coordinates, date: day, calculationParameters: parameters)
    else { return [] }
    return DailyPrayer.allCases.map { ScheduledPrayer(prayer: $0, time: times.time(for: $0.adhanPrayer)) }
  }

  func time(for prayer: DailyPrayer, on date: Date = Date()) -> Date? {
    prayers(on: date).first { $0.prayer == prayer }?.time
  }

  func nextPrayer(after date: Date = Date()) -> ScheduledPrayer? {
    guard let calendar = configuration?.calendar else { return nil }
    if let upcoming = prayers(on: date).first(where: { $0.time > date }) { return upcoming }
    guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
    return prayers(on: tomorrow).first { $0.time > date }
  }

  func formattedTime(for prayer: DailyPrayer, on date: Date = Date(), language: String) -> String? {
    guard let time = time(for: prayer, on: date),
      let identifier = configuration?.timeZoneIdentifier,
      let timeZone = TimeZone(identifier: identifier)
    else { return nil }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: language)
    formatter.timeZone = timeZone
    formatter.timeStyle = .short
    return formatter.string(from: time)
  }
}
