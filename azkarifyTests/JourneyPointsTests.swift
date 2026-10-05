import Foundation
import Testing

@testable import azkarify

struct JourneyPointsTests {
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
    let suite = "journey-points-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    return (JourneyProgressStore(defaults: defaults, calendar: calendar), defaults, suite)
  }

  @MainActor
  @Test func newlyCompletedStepsAndJourneyBonusAreAwardedOnlyOnce() {
    let (store, defaults, suite) = makeStore()
    defer { defaults.removePersistentDomain(forName: suite) }
    let journey = JourneyCatalog.evening

    #expect(store.totalPoints == 0)
    #expect(store.toggle(journey.steps[0], in: journey, on: today) == .completedJourney)
    #expect(store.totalPoints == JourneyProgressStore.stepPoints + JourneyProgressStore.journeyCompletionPoints)
    #expect(store.pointsEarned(on: today) == store.totalPoints)

    #expect(store.toggle(journey.steps[0], in: journey, on: today) == .reopened)
    #expect(store.totalPoints == 35)
    #expect(store.toggle(journey.steps[0], in: journey, on: today) == .completedJourney)
    #expect(store.totalPoints == 35)
  }

  @MainActor
  @Test func optionalCompletionAfterJourneyIsProgressOnlyAndCannotFarmPoints() {
    let (store, defaults, suite) = makeStore()
    defer { defaults.removePersistentDomain(forName: suite) }
    let journey = JourneyCatalog.goingOut
    let required = journey.steps[0]
    let optional = journey.steps[1]

    #expect(store.toggle(required, in: journey, on: today) == .completedJourney)
    #expect(store.totalPoints == 35)
    #expect(store.toggle(optional, in: journey, on: today) == .progressed)
    #expect(store.totalPoints == 45)
    #expect(store.toggle(optional, in: journey, on: today) == .reopened)
    #expect(store.toggle(optional, in: journey, on: today) == .progressed)
    #expect(store.totalPoints == 45)
  }

  @MainActor
  @Test func pointsAreScopedByDayAndJourney() {
    let (store, defaults, suite) = makeStore()
    defer { defaults.removePersistentDomain(forName: suite) }
    let todayJourney = JourneyCatalog.evening
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

    store.toggle(todayJourney.steps[0], in: todayJourney, on: today)
    store.toggle(todayJourney.steps[0], in: todayJourney, on: tomorrow)

    #expect(store.pointsEarned(on: today) == 35)
    #expect(store.pointsEarned(on: tomorrow) == 35)
    #expect(store.totalPoints == 70)
  }

  @MainActor
  @Test func distinctPrayerJourneysHaveIndependentAwardsOnTheSameDay() throws {
    let (store, defaults, suite) = makeStore()
    defer { defaults.removePersistentDomain(forName: suite) }
    let fajr = try #require(JourneyCatalog.prayers.first { $0.prayer == .fajr })
    let dhuhr = try #require(JourneyCatalog.prayers.first { $0.prayer == .dhuhr })

    for step in fajr.requiredSteps {
      store.toggle(step, in: fajr, on: today)
    }
    for step in dhuhr.requiredSteps {
      store.toggle(step, in: dhuhr, on: today)
    }

    let expected = (fajr.requiredSteps.count + dhuhr.requiredSteps.count)
      * JourneyProgressStore.stepPoints + 2 * JourneyProgressStore.journeyCompletionPoints
    #expect(store.totalPoints == expected)
    #expect(store.pointsEarned(on: today) == expected)
  }

  @MainActor
  @Test func pointsAndAwardsSurviveRelaunch() {
    let (store, defaults, suite) = makeStore()
    defer { defaults.removePersistentDomain(forName: suite) }
    let journey = JourneyCatalog.evening

    store.toggle(journey.steps[0], in: journey, on: today)
    let reloaded = JourneyProgressStore(defaults: defaults, calendar: calendar)

    #expect(reloaded.totalPoints == 35)
    #expect(reloaded.pointsEarned(on: today) == 35)
    #expect(reloaded.isComplete(journey, on: today))
    reloaded.toggle(journey.steps[0], in: journey, on: today)
    reloaded.toggle(journey.steps[0], in: journey, on: today)
    #expect(reloaded.totalPoints == 35)
  }

  @MainActor
  @Test func legacyProgressMigratesWithoutRetroactivePoints() throws {
    let (unusedStore, defaults, suite) = makeStore()
    _ = unusedStore
    defer { defaults.removePersistentDomain(forName: suite) }
    let journey = JourneyCatalog.morning
    let prayer = try #require(journey.steps.first { $0.id == "prayer" })
    var progress = JourneyProgress()
    progress.completedSteps = ["wake"]
    let legacy = ["1-2026-10-1": [journey.id: progress]]
    defaults.set(try! JSONEncoder().encode(legacy), forKey: "journey-progress.v1")

    let migrated = JourneyProgressStore(defaults: defaults, calendar: calendar)
    #expect(migrated.isComplete(journey.steps[0], in: journey, on: today))
    #expect(migrated.totalPoints == 0)
    #expect(migrated.pointsEarned(on: today) == 0)
    for step in journey.requiredSteps where step.id != prayer.id && step.id != "wake" {
      #expect(migrated.toggle(step, in: journey, on: today) == .progressed)
    }
    migrated.choose(prayer.options[0], for: prayer, in: journey, on: today)
    #expect(migrated.toggle(prayer, in: journey, on: today) == .completedJourney)
    #expect(migrated.totalPoints == 3 * JourneyProgressStore.stepPoints
      + JourneyProgressStore.journeyCompletionPoints)
    let reloaded = JourneyProgressStore(defaults: defaults, calendar: calendar)
    #expect(reloaded.totalPoints == 55)
    reloaded.toggle(prayer, in: journey, on: today)
    reloaded.toggle(prayer, in: journey, on: today)
    #expect(reloaded.totalPoints == 55)
  }

  @MainActor
  @Test func invalidAndUnselectedStepsDoNotAwardPoints() throws {
    let (store, defaults, suite) = makeStore()
    defer { defaults.removePersistentDomain(forName: suite) }
    let journey = JourneyCatalog.morning
    let prayer = try #require(journey.steps.first { $0.id == "prayer" })
    let unrelated = JourneyStep("other", "Other", "أخرى")

    #expect(store.toggle(unrelated, in: journey, on: today) == .unchanged)
    #expect(store.toggle(prayer, in: journey, on: today) == .unchanged)
    #expect(store.totalPoints == 0)
  }

  @MainActor
  @Test func changingPrayerChoiceDoesNotReawardCompletedStepOrJourney() throws {
    let (store, defaults, suite) = makeStore()
    defer { defaults.removePersistentDomain(forName: suite) }
    let journey = JourneyCatalog.morning
    let prayer = try #require(journey.steps.first { $0.id == "prayer" })

    for step in journey.requiredSteps where step.id != prayer.id {
      store.toggle(step, in: journey, on: today)
    }
    store.choose(prayer.options[0], for: prayer, in: journey, on: today)
    #expect(store.toggle(prayer, in: journey, on: today) == .completedJourney)
    #expect(store.totalPoints == 4 * JourneyProgressStore.stepPoints
      + JourneyProgressStore.journeyCompletionPoints)

    store.choose(prayer.options[1], for: prayer, in: journey, on: today)
    #expect(!store.isComplete(journey, on: today))
    #expect(store.toggle(prayer, in: journey, on: today) == .completedJourney)
    #expect(store.totalPoints == 65)
  }
  @MainActor
  @Test func slideshowAwardsThirtyPointsOncePerCategoryPerDay() {
    let (store, defaults, suite) = makeStore()
    defer { defaults.removePersistentDomain(forName: suite) }
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

    #expect(store.completeSlideshow(categoryID: 9, on: today))
    #expect(store.totalPoints == 30)
    #expect(store.completeSlideshow(categoryID: 9, on: today) == false)
    #expect(store.totalPoints == 30)
    #expect(store.completeSlideshow(categoryID: 20, on: today))
    #expect(store.pointsEarned(on: today) == 60)
    #expect(store.completeSlideshow(categoryID: 9, on: tomorrow))
    #expect(store.pointsEarned(on: tomorrow) == 30)
    #expect(store.totalPoints == 90)
    #expect(store.completedJourneyCount(on: today) == 0)
    #expect(store.dayProgress(on: today) == 0)
  }

  @MainActor
  @Test func slideshowPointsAndDuplicateProtectionSurviveRelaunch() {
    let (store, defaults, suite) = makeStore()
    defer { defaults.removePersistentDomain(forName: suite) }
    store.completeSlideshow(categoryID: 9, on: today)

    let reloaded = JourneyProgressStore(defaults: defaults, calendar: calendar)
    #expect(reloaded.totalPoints == 30)
    #expect(reloaded.pointsEarned(on: today) == 30)
    #expect(reloaded.completeSlideshow(categoryID: 9, on: today) == false)
    #expect(reloaded.totalPoints == 30)
  }

  @MainActor
  @Test func existingV2PointsSurviveSlideshowRewards() throws {
    let (_, defaults, suite) = makeStore()
    defer { defaults.removePersistentDomain(forName: suite) }
    let existing = """
      {"version":2,"records":{},"awards":{"existing":{
        "id":"existing","dayKey":"1-2026-10-1","journeyID":"morning",
        "stepID":"wake","timestamp":0,"amount":10,"reason":"journey-step-completed"
      }}}
      """
    defaults.set(try #require(existing.data(using: .utf8)), forKey: "journey-progress.v2")
    let store = JourneyProgressStore(defaults: defaults, calendar: calendar)
    #expect(store.totalPoints == 10)
    store.completeSlideshow(categoryID: 9, on: today)
    #expect(store.totalPoints == 40)

    let reloaded = JourneyProgressStore(defaults: defaults, calendar: calendar)
    #expect(reloaded.totalPoints == 40)
    #expect(reloaded.pointsEarned(on: today) == 40)
  }

}
