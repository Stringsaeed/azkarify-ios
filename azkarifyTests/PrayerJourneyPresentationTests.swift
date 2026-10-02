import Foundation
import Testing

@testable import azkarify

struct PrayerJourneyPresentationTests {
  private var calendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(secondsFromGMT: 4 * 60 * 60)!
    return value
  }

  private var today: Date {
    calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 12))!
  }

  @MainActor
  private func makeStore() -> (JourneyProgressStore, UserDefaults, String) {
    let suite = "prayer-journey-presentation-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    return (JourneyProgressStore(defaults: defaults, calendar: calendar), defaults, suite)
  }

  @MainActor
  @Test func prayerJourneyCountsFiveOfEightBeforeCompletingAllSteps() throws {
    let (store, defaults, suite) = makeStore()
    defer { defaults.removePersistentDomain(forName: suite) }
    let journey = try #require(JourneyCatalog.prayers.first)

    #expect(journey.steps.count == 8)
    #expect(journey.requiredSteps.count == 8)
    #expect(journey.steps.dropFirst(5).allSatisfy { !$0.isOptional })

    for step in journey.steps.prefix(5) {
      #expect(store.toggle(step, in: journey, on: today) == .progressed)
    }

    #expect(store.completedCount(for: journey, on: today) == 5)
    #expect(!store.isComplete(journey, on: today))

    for step in journey.steps.dropFirst(5) {
      let update = store.toggle(step, in: journey, on: today)
      #expect(update == .progressed || update == .completedJourney)
    }

    #expect(store.completedCount(for: journey, on: today) == 8)
    #expect(store.isComplete(journey, on: today))
  }

  @MainActor
  @Test func anExistingCompletionBonusIsPreservedAndNotAwardedAgain() throws {
    let (unusedStore, defaults, suite) = makeStore()
    _ = unusedStore
    defer { defaults.removePersistentDomain(forName: suite) }
    let journey = try #require(JourneyCatalog.prayers.first)
    let dateKey = "1-2026-10-1"
    let oldRequiredSteps = journey.steps.filter { $0.id == "wudu" || $0.id == "adhan"
      || $0.id == "before-iqama" || $0.id == "prayer" || $0.id == "after-prayer" }
    var progress = JourneyProgress()
    progress.completedSteps = Set(oldRequiredSteps.map(\.id))

    let awards = oldRequiredSteps.map { step in
      SeedJourneyAward(
        id: "journey-step|\(dateKey)|\(journey.id)|\(step.id)",
        dayKey: dateKey,
        journeyID: journey.id,
        stepID: step.id,
        timestamp: today,
        amount: JourneyProgressStore.stepPoints,
        reason: "journey-step-completed")
    } + [SeedJourneyAward(
      id: "journey-bonus|\(dateKey)|\(journey.id)",
      dayKey: dateKey,
      journeyID: journey.id,
      stepID: nil,
      timestamp: today,
      amount: JourneyProgressStore.journeyCompletionPoints,
      reason: "journey-completed")]
    let seeded = SeedJourneyPayload(
      version: 2,
      records: [dateKey: [journey.id: progress]],
      awards: Dictionary(uniqueKeysWithValues: awards.map { ($0.id, $0) }))
    defaults.set(try JSONEncoder().encode(seeded), forKey: "journey-progress.v2")

    let store = JourneyProgressStore(defaults: defaults, calendar: calendar)
    #expect(store.totalPoints == 5 * JourneyProgressStore.stepPoints
      + JourneyProgressStore.journeyCompletionPoints)
    #expect(!store.isComplete(journey, on: today))

    for step in journey.steps where !progress.completedSteps.contains(step.id) {
      let update = store.toggle(step, in: journey, on: today)
      #expect(update == .progressed || update == .completedJourney)
    }

    #expect(store.isComplete(journey, on: today))
    #expect(store.totalPoints == 8 * JourneyProgressStore.stepPoints
      + JourneyProgressStore.journeyCompletionPoints)
  }

  @Test func nextPrayerSkipsCompletedJourneysInChronologicalOrder() {
    let prayers = scheduledPrayers(at: [
      (.asr, 15), (.fajr, 5), (.dhuhr, 12), (.isha, 20)
    ])

    #expect(PrayerJourneyHighlight.nextJourneyID(
      on: date(hour: 10),
      prayers: prayers,
      completedJourneyIDs: ["prayer-dhuhr"]) == "prayer-asr")
  }

  @Test func nextPrayerReturnsNilAfterIshaWithoutNextDayFallback() {
    let prayers = scheduledPrayers(at: [
      (.fajr, 5), (.dhuhr, 12), (.asr, 15), (.maghrib, 18), (.isha, 20)
    ])

    #expect(PrayerJourneyHighlight.nextJourneyID(
      on: date(hour: 21), prayers: prayers, completedJourneyIDs: []) == nil)
  }

  @Test func nextPrayerReturnsNilWhenEveryRemainingPrayerIsComplete() {
    let prayers = scheduledPrayers(at: [(.fajr, 5), (.dhuhr, 12), (.asr, 15)])
    let completed = Set(prayers.map { "prayer-\($0.prayer.rawValue)" })

    #expect(PrayerJourneyHighlight.nextJourneyID(
      on: date(hour: 4), prayers: prayers, completedJourneyIDs: completed) == nil)
  }

  private func date(hour: Int) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: hour))!
  }

  private func scheduledPrayers(at values: [(DailyPrayer, Int)]) -> [ScheduledPrayer] {
    values.map { prayer, hour in ScheduledPrayer(prayer: prayer, time: date(hour: hour)) }
  }
}

private struct SeedJourneyPayload: Codable {
  let version: Int
  let records: [String: [String: JourneyProgress]]
  let awards: [String: SeedJourneyAward]
}

private struct SeedJourneyAward: Codable {
  let id: String
  let dayKey: String
  let journeyID: String
  let stepID: String?
  let timestamp: Date
  let amount: Int
  let reason: String
}
