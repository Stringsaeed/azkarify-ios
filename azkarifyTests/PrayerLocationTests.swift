import CoreLocation
import Foundation
import Testing

@testable import azkarify

@MainActor
struct PrayerLocationTests {
  @Test func localConfigurationUsesCoordinatesTimezoneAndArabicLabel() {
    let timeZone = TimeZone(identifier: "Asia/Dubai")!
    let configuration = PrayerLocationProvider.localConfiguration(
      latitude: 25.2048,
      longitude: 55.2708,
      language: "ar",
      timeZone: timeZone)

    #expect(configuration.locationName == "الموقع الحالي")
    #expect(configuration.latitude == 25.2048)
    #expect(configuration.longitude == 55.2708)
    #expect(configuration.timeZoneIdentifier == "Asia/Dubai")
    #expect(configuration.method == .dubai)
    #expect(configuration.madhab == .shafi)
    #expect(configuration.isValid)
  }

  @Test func localConfigurationUsesEnglishLabelAndFallsBackToMuslimWorldLeague() {
    let timeZone = TimeZone(identifier: "Pacific/Auckland")!
    let configuration = PrayerLocationProvider.localConfiguration(
      latitude: -36.8509,
      longitude: 174.7645,
      language: "en",
      timeZone: timeZone)

    #expect(configuration.locationName == "Current location")
    #expect(configuration.method == .muslimWorldLeague)
    #expect(configuration.timeZoneIdentifier == "Pacific/Auckland")
  }

  @Test func deviceLocationLabelFollowsAppLanguage() {
    let configuration = PrayerLocationProvider.localConfiguration(
      latitude: 25.2048, longitude: 55.2708, language: "en",
      timeZone: TimeZone(identifier: "Asia/Dubai")!)

    #expect(configuration.displayLocationName(language: "en") == "Current location")
    #expect(configuration.displayLocationName(language: "ar") == "الموقع الحالي")
  }

  @Test func cityNameFollowsAppLanguage() {
    let dubai = PrayerCity.cities.first { $0.id == "Dubai" }!
    let configuration = PrayerScheduleConfiguration(
      city: dubai, madhab: .shafi, ishaAdjustmentMinutes: 0, language: "ar")

    #expect(configuration.locationName == "دبي")
    #expect(configuration.displayLocationName(language: "en") == "Dubai")
    #expect(configuration.displayLocationName(language: "ar") == "دبي")
  }

  @Test func typedLocationNameIsShownAsTyped() {
    let dubai = PrayerCity.cities.first { $0.id == "Dubai" }!
    var configuration = PrayerScheduleConfiguration(
      city: dubai, madhab: .shafi, ishaAdjustmentMinutes: 0, language: "en")
    configuration.locationName = "Home"

    #expect(configuration.displayLocationName(language: "ar") == "Home")
  }

  @Test func olderSavedConfigurationsGetLocalizedLabels() throws {
    func decode(_ json: String) throws -> PrayerScheduleConfiguration {
      try JSONDecoder().decode(PrayerScheduleConfiguration.self, from: Data(json.utf8))
    }
    let city = try decode("""
      {"locationName":"دبي","latitude":25.2048,"longitude":55.2708,"timeZoneIdentifier":"Asia/Dubai",
      "method":"dubai","madhab":"shafi","ishaAdjustmentMinutes":0,"countryCode":"AE","cityID":"Dubai"}
      """)
    let device = try decode("""
      {"locationName":"Current location","latitude":25.2048,"longitude":55.2708,
      "timeZoneIdentifier":"Asia/Dubai","method":"dubai","madhab":"shafi","ishaAdjustmentMinutes":0}
      """)

    #expect(city.displayLocationName(language: "en") == "Dubai")
    #expect(!city.usesDeviceLocation)
    #expect(device.usesDeviceLocation)
    #expect(device.displayLocationName(language: "ar") == "الموقع الحالي")
  }

  @Test func invalidStaleAndInaccurateLocationsAreRejected() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let invalid = CLLocation(
      coordinate: CLLocationCoordinate2D(latitude: 91, longitude: 0),
      altitude: 0,
      horizontalAccuracy: 10,
      verticalAccuracy: 10,
      timestamp: now)
    let stale = CLLocation(
      coordinate: CLLocationCoordinate2D(latitude: 25, longitude: 55),
      altitude: 0,
      horizontalAccuracy: 10,
      verticalAccuracy: 10,
      timestamp: now.addingTimeInterval(-301))
    let inaccurate = CLLocation(
      coordinate: CLLocationCoordinate2D(latitude: 25, longitude: 55),
      altitude: 0,
      horizontalAccuracy: 100_001,
      verticalAccuracy: 10,
      timestamp: now)

    #expect(!PrayerLocationProvider.isUsableLocation(invalid, now: now))
    #expect(!PrayerLocationProvider.isUsableLocation(stale, now: now))
    #expect(!PrayerLocationProvider.isUsableLocation(inaccurate, now: now))
  }

  @Test func realisticReducedAccuracyLocationIsAccepted() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let reducedAccuracy = CLLocation(
      coordinate: CLLocationCoordinate2D(latitude: 25.2048, longitude: 55.2708),
      altitude: 0,
      horizontalAccuracy: 1_000,
      verticalAccuracy: 1_000,
      timestamp: now)

    #expect(PrayerLocationProvider.isUsableLocation(reducedAccuracy, now: now))
  }
}
