import Foundation
import Testing

@testable import azkarify

struct CountrySelectionTests {
  @Test func defaultCountryUsesLocaleRegionIndependentlyOfLanguage() {
    #expect(PrayerCountryCatalog.defaultCountryCode(locale: Locale(identifier: "en_AE")) == "AE")
    #expect(PrayerCountryCatalog.defaultCountryCode(locale: Locale(identifier: "ar_AE")) == "AE")
  }

  @Test func localeWithoutRegionRequiresAnExplicitCountryChoice() {
    #expect(PrayerCountryCatalog.defaultCountryCode(locale: Locale(identifier: "ar")) == "")
  }

  @Test func catalogContainsLocalizedCountryMetadata() throws {
    let unitedArabEmirates = try #require(PrayerCountryCatalog.country(for: "ae"))
    #expect(unitedArabEmirates.code == "AE")
    #expect(!unitedArabEmirates.name(language: "en").isEmpty)
    #expect(!unitedArabEmirates.name(language: "ar").isEmpty)
  }

  @Test func bundledCitiesAreAssociatedWithTheirCountry() {
    #expect(PrayerCity.cities(for: "AE").map(\.id) == ["Dubai", "Abu Dhabi"])
    #expect(PrayerCity.cities(for: "EG").map(\.id) == ["Cairo"])
    #expect(PrayerCity.cities(for: "ZZ").isEmpty)
    #expect(PrayerCountryCatalog.countryCode(for: "Dubai") == "AE")
    #expect(PrayerCountryCatalog.countryCode(for: "القاهرة") == "EG")
  }
}
