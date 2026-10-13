import Foundation
import Testing

@testable import azkarify

struct GuideCatalogTests {
  @MainActor
  @Test func beatsSkipCategory21() throws {
    for language in ["en", "ar"] {
      let beats = try GuideCatalog.beats(language: language, repository: AzkarRepository())
      #expect(beats.allSatisfy { $0.categoryID != 21 })
      #expect(beats.first?.categoryID == 16)
      #expect(beats.first?.entryID == 27)
      #expect(beats.last?.categoryID == 25)
      #expect(beats.last?.entryID == 73)
    }
  }

  @MainActor
  @Test func beatCountIs45() throws {
    for language in ["en", "ar"] {
      let start = ContinuousClock.now
      let beats = try GuideCatalog.beats(language: language, repository: AzkarRepository())
      let elapsed = start.duration(to: .now)
      #expect(beats.count == 45)
      #expect(beats.allSatisfy { $0.kidsLine == nil })
      #expect(elapsed < .milliseconds(50))
    }
  }

  @MainActor
  @Test func englishCategory25Entry66RepeatsOnce() throws {
    let beat = try loadBeat(language: "en", entryID: 66)
    #expect(beat.categoryID == 25)
    #expect(beat.repeatCount == 1)
  }

  @MainActor
  @Test func arabicCategory25Entry66RepeatsThreeTimes() throws {
    let beat = try loadBeat(language: "ar", entryID: 66)
    #expect(beat.categoryID == 25)
    #expect(beat.repeatCount == 3)
  }

  @MainActor
  @Test func arabicCategory16Entry31RepeatsThreeTimes() throws {
    let beat = try loadBeat(language: "ar", entryID: 31)
    #expect(beat.categoryID == 16)
    #expect(beat.repeatCount == 3)
    let english = try loadBeat(language: "en", entryID: 31)
    #expect(english.repeatCount == 1)
  }

  @MainActor
  @Test func category25Entry69Repeats33Times() throws {
    for language in ["en", "ar"] {
      let beat = try loadBeat(language: language, entryID: 69)
      #expect(beat.categoryID == 25)
      #expect(beat.repeatCount == 33)
    }
  }

  @MainActor
  @Test func posturesMatchCategories() throws {
    let expected = [
      16: "GuideStanding",
      17: "JourneyCrescent",
      18: "GuideStanding",
      19: "GuideProstrating",
      20: "GuideSitting",
      22: "GuideSitting",
      23: "GuideSitting",
      24: "GuideSitting",
      25: "GuideAfter",
    ]
    let beats = try GuideCatalog.beats(language: "en", repository: AzkarRepository())
    for beat in beats {
      #expect(beat.posture == expected[beat.categoryID])
    }
    let bow = try #require(beats.first { $0.categoryID == 17 })
    #expect(bow.posture == "JourneyCrescent")
    let rising = try #require(beats.first { $0.categoryID == 18 })
    let between = try #require(beats.first { $0.categoryID == 20 })
    #expect(rising.posture == "GuideStanding")
    #expect(between.posture == "GuideSitting")
  }

  @MainActor
  private func loadBeat(language: String, entryID: Int) throws -> GuideBeat {
    let beats = try GuideCatalog.beats(language: language, repository: AzkarRepository())
    return try #require(beats.first { $0.entryID == entryID })
  }
}
