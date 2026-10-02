import CountryKit
import Foundation

/// The country metadata used by the prayer location pickers.
///
/// CountryKit owns the country list and ISO data. This small value type keeps
/// the views independent of CountryKit's model while allowing names to follow
/// the language selected in the app.
struct PrayerCountry: Identifiable, Equatable, Codable {
  let code: String
  let englishName: String
  let arabicName: String
  let flag: String?
  let method: PrayerCalculationMethod?

  var id: String { code }

  init(country: Country) {
    self.code = country.alpha2Code.uppercased()
    self.englishName = country.name
    self.arabicName = country.translation(for: Locale(identifier: "ar")) ?? country.name
    self.flag = nil
    self.method = nil
  }

  init(
    code: String,
    englishName: String,
    arabicName: String,
    flag: String? = nil,
    method: PrayerCalculationMethod? = nil
  ) {
    self.code = code.uppercased()
    self.englishName = englishName
    self.arabicName = arabicName.isEmpty ? englishName : arabicName
    self.flag = flag
    self.method = method
  }

  func name(language: String) -> String {
    language.hasPrefix("ar") && !arabicName.isEmpty ? arabicName : englishName
  }
}

enum PrayerCountryCatalog {
  private static let provider = WorldProvider()

  /// All countries are available for browsing, even when this app has no
  /// bundled city for the selected country.
  static let countries: [PrayerCountry] = provider.countries
    .map { PrayerCountry(country: $0) }
    .sorted { $0.englishName.localizedCaseInsensitiveCompare($1.englishName) == .orderedAscending }

  private static let countriesByCode = Dictionary(
    uniqueKeysWithValues: countries.map { ($0.code, $0) })

  static func country(for code: String?) -> PrayerCountry? {
    guard let code else { return nil }
    return countriesByCode[code.uppercased()]
  }

  /// Uses the device's regional setting only. The language preference and
  /// device location are intentionally not used as a country guess. An empty
  /// result means that the user must choose a country before browsing cities.
  static func defaultCountryCode(locale: Locale = .current) -> String {
    let regionCode = locale.region?.identifier.uppercased()
    if let regionCode, countriesByCode[regionCode] != nil {
      return regionCode
    }
    return ""
  }

  static func countryCode(for cityName: String) -> String? {
    let normalizedName = cityName.trimmingCharacters(in: .whitespacesAndNewlines)
    return PrayerCity.cities.first {
      $0.id.caseInsensitiveCompare(normalizedName) == .orderedSame
        || $0.arabicName == normalizedName
    }?.countryCode
  }

  static func isAlpha2Code(_ code: String) -> Bool {
    let uppercased = code.uppercased()
    guard uppercased.count == 2 else { return false }
    return uppercased.unicodeScalars.allSatisfy { scalar in
      (65...90).contains(scalar.value)
    }
  }
}
