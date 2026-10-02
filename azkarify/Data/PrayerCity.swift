import Foundation

struct PrayerCity: Identifiable, Equatable {
  let id: String
  let englishName: String
  let arabicName: String
  let countryCode: String
  let region: String?
  let latitude: Double
  let longitude: Double
  let timeZone: String
  let method: PrayerCalculationMethod

  init(
    id: String,
    arabicName: String,
    countryCode: String,
    latitude: Double,
    longitude: Double,
    timeZone: String,
    method: PrayerCalculationMethod,
    region: String? = nil
  ) {
    self.init(
      id: id,
      englishName: id,
      arabicName: arabicName,
      countryCode: countryCode,
      latitude: latitude,
      longitude: longitude,
      timeZone: timeZone,
      method: method,
      region: region)
  }

  init(
    id: String,
    englishName: String,
    arabicName: String,
    countryCode: String,
    latitude: Double,
    longitude: Double,
    timeZone: String,
    method: PrayerCalculationMethod,
    region: String? = nil
  ) {
    self.id = id
    self.englishName = englishName
    self.arabicName = arabicName
    self.countryCode = countryCode.uppercased()
    let trimmedRegion = region?.trimmingCharacters(in: .whitespacesAndNewlines)
    self.region = trimmedRegion?.isEmpty == true ? nil : trimmedRegion
    self.latitude = latitude
    self.longitude = longitude
    self.timeZone = timeZone
    self.method = method
  }

  func name(language: String) -> String {
    language.hasPrefix("ar") && !arabicName.isEmpty ? arabicName : englishName
  }

  static let cities: [PrayerCity] = [
    .init(id: "Dubai", arabicName: "دبي", countryCode: "AE", latitude: 25.2048, longitude: 55.2708,
      timeZone: "Asia/Dubai", method: .dubai),
    .init(id: "Abu Dhabi", arabicName: "أبو ظبي", countryCode: "AE", latitude: 24.4539, longitude: 54.3773,
      timeZone: "Asia/Dubai", method: .dubai),
    .init(id: "Cairo", arabicName: "القاهرة", countryCode: "EG", latitude: 30.0444, longitude: 31.2357,
      timeZone: "Africa/Cairo", method: .egyptian),
    .init(id: "Makkah", arabicName: "مكة المكرمة", countryCode: "SA", latitude: 21.4225, longitude: 39.8262,
      timeZone: "Asia/Riyadh", method: .ummAlQura),
    .init(id: "Madinah", arabicName: "المدينة المنورة", countryCode: "SA", latitude: 24.4672, longitude: 39.6111,
      timeZone: "Asia/Riyadh", method: .ummAlQura),
    .init(id: "Riyadh", arabicName: "الرياض", countryCode: "SA", latitude: 24.7136, longitude: 46.6753,
      timeZone: "Asia/Riyadh", method: .ummAlQura),
    .init(id: "Doha", arabicName: "الدوحة", countryCode: "QA", latitude: 25.2854, longitude: 51.5310,
      timeZone: "Asia/Qatar", method: .qatar),
    .init(id: "Kuwait City", arabicName: "مدينة الكويت", countryCode: "KW", latitude: 29.3759, longitude: 47.9774,
      timeZone: "Asia/Kuwait", method: .kuwait),
    .init(id: "London", arabicName: "لندن", countryCode: "GB", latitude: 51.5074, longitude: -0.1278,
      timeZone: "Europe/London", method: .moonsightingCommittee),
    .init(id: "New York", arabicName: "نيويورك", countryCode: "US", latitude: 40.7128, longitude: -74.0060,
      timeZone: "America/New_York", method: .moonsightingCommittee),
    .init(id: "Singapore", arabicName: "سنغافورة", countryCode: "SG", latitude: 1.3521, longitude: 103.8198,
      timeZone: "Asia/Singapore", method: .singapore),
  ]

  static func cities(for countryCode: String) -> [PrayerCity] {
    cities.filter { $0.countryCode.caseInsensitiveCompare(countryCode) == .orderedSame }
  }
}
