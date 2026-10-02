import Foundation
import Testing

@testable import azkarify

struct JourneyTests {
  @MainActor
  @Test func dailyProgressIncludesPartialJourneysAndResetsTomorrow() throws {
    let (store, defaults, suite) = makeStore()
    defer { defaults.removePersistentDomain(forName: suite) }
    #expect(store.dayProgress(on: today) == 0)
    let sleep = JourneyCatalog.sleep
    store.toggle(sleep.steps[1], in: sleep, on: today)
    #expect(store.dayProgress(on: today) == 0)
    store.toggle(JourneyCatalog.morning.steps[0], in: JourneyCatalog.morning, on: today)
    #expect(abs(store.dayProgress(on: today) - 1.0 / 47.0) < 0.000001)
    for journey in JourneyCatalog.all {
      for step in journey.requiredSteps {
        if let option = step.options.first {
          store.choose(option, for: step, in: journey, on: today)
        }
        if !store.isComplete(step, in: journey, on: today) {
          store.toggle(step, in: journey, on: today)
        }
      }
    }
    #expect(store.dayProgress(on: today) == 1)
    store.toggle(sleep.steps[0], in: sleep, on: today)
    #expect(abs(store.dayProgress(on: today) - 46.0 / 47.0) < 0.000001)
    let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: today))
    #expect(store.dayProgress(on: tomorrow) == 0)
  }

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
    let suite = "journey-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    return (JourneyProgressStore(defaults: defaults, calendar: calendar), defaults, suite)
  }

  @MainActor
  @Test func completingRequiredStepsDoesNotRequireOptionalNightAzkar() {
    let (store, defaults, suite) = makeStore()
    defer { defaults.removePersistentDomain(forName: suite) }
    let journey = JourneyCatalog.sleep
    store.toggle(journey.steps[0], in: journey, on: today)
    #expect(store.isComplete(journey, on: today))
    #expect(store.completedCount(for: journey, on: today) == 1)
    #expect(!store.isComplete(journey.steps[1], in: journey, on: today))
    store.toggle(journey.steps[1], in: journey, on: today)
    #expect(store.completedCount(for: journey, on: today) == 1)
    store.toggle(journey.steps[0], in: journey, on: today)
    #expect(!store.isComplete(journey, on: today))
  }

  @MainActor
  @Test func morningRequiresOnePrayerChoiceAndChangingItClearsOnlyThatStep() throws {
    let (store, defaults, suite) = makeStore()
    defer { defaults.removePersistentDomain(forName: suite) }
    let journey = JourneyCatalog.morning
    let prayer = try #require(journey.steps.first { $0.id == "prayer" })
    for step in journey.steps { store.toggle(step, in: journey, on: today) }
    #expect(!store.isComplete(journey, on: today))
    #expect(store.completedCount(for: journey, on: today) == 3)
    store.choose(prayer.options[1], for: prayer, in: journey, on: today)
    store.toggle(prayer, in: journey, on: today)
    #expect(store.isComplete(journey, on: today))
    #expect(store.progress(for: journey, on: today).choices["prayer"] == "duha")
    store.choose(prayer.options[0], for: prayer, in: journey, on: today)
    #expect(!store.isComplete(prayer, in: journey, on: today))
    #expect(store.completedCount(for: journey, on: today) == 3)
    store.toggle(prayer, in: journey, on: today)
    #expect(store.isComplete(journey, on: today))
  }

  @MainActor
  @Test func progressPersistsPerPrayerAndResetsAtLocalMidnight() throws {
    let (store, defaults, suite) = makeStore()
    defer { defaults.removePersistentDomain(forName: suite) }
    let fajr = try #require(JourneyCatalog.prayers.first { $0.prayer == .fajr })
    let dhuhr = try #require(JourneyCatalog.prayers.first { $0.prayer == .dhuhr })
    for step in fajr.requiredSteps { store.toggle(step, in: fajr, on: today) }
    let reloaded = JourneyProgressStore(defaults: defaults, calendar: calendar)
    #expect(reloaded.isComplete(fajr, on: today))
    #expect(reloaded.completedCount(for: dhuhr, on: today) == 0)
    let beforeMidnight = try #require(calendar.date(from: DateComponents(
      year: 2026, month: 10, day: 1, hour: 23, minute: 59)))
    let afterMidnight = beforeMidnight.addingTimeInterval(60)
    #expect(reloaded.isComplete(fajr, on: beforeMidnight))
    #expect(reloaded.completedCount(for: fajr, on: afterMidnight) == 0)
    #expect(reloaded.completedJourneyCount(on: today) == 1)
    #expect(reloaded.completedJourneyCount(on: afterMidnight) == 0)
  }

  @MainActor
  @Test(arguments: ["ar", "en"])
  func everyJourneyLinksOnlyExistingBundledCategories(language: String) throws {
    let repository = AzkarRepository()
    let categories = try repository.categories(language: language)
    let knownIDs = Set(categories.map(\.id))
    #expect(JourneyCatalog.all.count == 9)
    #expect(Set(JourneyCatalog.all.map(\.id)).count == 9)
    #expect(Set(JourneyCatalog.prayers.compactMap(\.prayer)).count == 5)
    for journey in JourneyCatalog.all {
      #expect(!journey.requiredSteps.isEmpty)
      #expect(Set(journey.steps.map(\.id)).count == journey.steps.count)
      #expect(!journey.title.value(language: language).isEmpty)
      for step in journey.steps {
        #expect(!step.title.value(language: language).isEmpty)
        #expect(Set(step.categoryIDs).isSubset(of: knownIDs))
        for id in step.categoryIDs {
          let category = try #require(categories.first { $0.id == id })
          #expect(try !repository.entries(for: category).isEmpty)
        }
      }
    }
  }
}
