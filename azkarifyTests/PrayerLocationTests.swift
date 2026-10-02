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
