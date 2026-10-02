import Foundation
import Testing

@testable import azkarify

@MainActor
struct PrayerScheduleTests {
  private func isolatedDefaults() -> UserDefaults {
    UserDefaults(suiteName: "PrayerScheduleTests.\(UUID().uuidString)")!
  }

  private var raleigh: PrayerScheduleConfiguration {
    PrayerScheduleConfiguration(
      locationName: "Raleigh", latitude: 35.7750, longitude: -78.6336,
      timeZoneIdentifier: "America/New_York", method: .northAmerica, madhab: .hanafi)
  }

  private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

  @Test func noPrayerTimesUntilLocationIsConfigured() {
    let store = PrayerScheduleStore(defaults: isolatedDefaults())
    #expect(store.configuration == nil)
    #expect(store.schedule.isEmpty)
    #expect(store.time(for: .fajr) == nil)
    #expect(store.nextPrayer() == nil)
  }

  @Test func matchesAdhanReferenceTimesUsingConfiguredLocalDay() throws {
    // Adhan 1.5.0's testPrayerTimes reference for Raleigh on July 12, 2015.
    let store = PrayerScheduleStore(defaults: isolatedDefaults())
    try store.save(raleigh)
    let prayers = store.prayers(on: date("2015-07-13T00:00:00Z"))
    #expect(prayers.map(\.prayer) == [.fajr, .dhuhr, .asr, .maghrib, .isha])
    #expect(prayers.map(\.time) == [
      date("2015-07-12T08:42:00Z"), date("2015-07-12T17:21:00Z"),
      date("2015-07-12T22:22:00Z"), date("2015-07-13T00:32:00Z"),
      date("2015-07-13T01:57:00Z"),
    ])
  }

  @Test func sunriseIsNotNextPrayerAndIshaRollsOverToTomorrowFajr() throws {
    let store = PrayerScheduleStore(defaults: isolatedDefaults())
    try store.save(raleigh)
    let afterFajr = date("2015-07-12T09:00:00Z")
    #expect(store.nextPrayer(after: afterFajr)?.prayer == .dhuhr)
    #expect(store.nextPrayer(after: afterFajr)?.time == date("2015-07-12T17:21:00Z"))
    let afterIsha = date("2015-07-13T02:00:00Z")
    let next = try #require(store.nextPrayer(after: afterIsha))
    #expect(next.prayer == .fajr)
    #expect(next.time > afterIsha)
    let calendar = try #require(raleigh.calendar)
    #expect(calendar.component(.day, from: next.time) == 13)
  }

  @Test func savedConfigurationSurvivesRelaunchAndClearRemovesTimes() throws {
    let defaults = isolatedDefaults()
    let store = PrayerScheduleStore(defaults: defaults)
    try store.save(raleigh)
    let reopened = PrayerScheduleStore(defaults: defaults)
    #expect(reopened.configuration == raleigh)
    #expect(reopened.schedule.count == 5)
    reopened.clear()
    #expect(reopened.schedule.isEmpty)
    #expect(PrayerScheduleStore(defaults: defaults).configuration == nil)
  }

  @Test func invalidCoordinatesAndTimeZoneCannotCreateSchedule() {
    let store = PrayerScheduleStore(defaults: isolatedDefaults())
    var invalid = raleigh
    invalid.latitude = 91
    #expect(throws: PrayerScheduleError.self) { try store.save(invalid) }
    invalid = raleigh
    invalid.longitude = .infinity
    #expect(throws: PrayerScheduleError.self) { try store.save(invalid) }
    invalid = raleigh
    invalid.timeZoneIdentifier = "Missing/TimeZone"
    #expect(throws: PrayerScheduleError.self) { try store.save(invalid) }
    #expect(store.configuration == nil)
  }

  @Test func hanafiChangesAsrAndIshaAdjustmentAppliesOnlyToIsha() throws {
    let store = PrayerScheduleStore(defaults: isolatedDefaults())
    let day = date("2015-07-12T12:00:00Z")
    try store.save(raleigh)
    let hanafi = store.prayers(on: day)
    var changed = raleigh
    changed.madhab = .shafi
    try store.save(changed)
    let shafi = store.prayers(on: day)
    let hanafiAsr = try #require(hanafi.first { $0.prayer == .asr }?.time)
    let shafiAsr = try #require(shafi.first { $0.prayer == .asr }?.time)
    #expect(hanafiAsr > shafiAsr)
    #expect(hanafi.filter { $0.prayer != .asr } == shafi.filter { $0.prayer != .asr })
    changed.ishaAdjustmentMinutes = 30
    try store.save(changed)
    let adjusted = store.prayers(on: day)
    #expect(adjusted.filter { $0.prayer != .isha } == shafi.filter { $0.prayer != .isha })
    #expect(adjusted.last?.time == shafi.last?.time.addingTimeInterval(1800))
  }

  @Test func polarDayReturnsUnavailableInsteadOfFabricatedTimes() throws {
    let store = PrayerScheduleStore(defaults: isolatedDefaults())
    try store.save(PrayerScheduleConfiguration(
      locationName: "Longyearbyen", latitude: 78.2232, longitude: 15.6469,
      timeZoneIdentifier: "Arctic/Longyearbyen", method: .muslimWorldLeague, madhab: .shafi))
    #expect(store.prayers(on: date("2026-06-21T12:00:00Z")).isEmpty)
  }
}
