import Foundation
import Testing

@testable import azkarify

struct GuideCatalogTests {
  @MainActor
  @Test func chaptersSkipCategory21() throws {
    for language in ["en", "ar"] {
      let chapters = try GuideCatalog.load(language: language, repository: AzkarRepository())
      #expect(chapters.map(\.categoryID) == [16, 17, 18, 19, 20, 22, 23, 24, 25])
      #expect(!chapters.contains { $0.categoryID == 21 })
      let first = try #require(chapters.first?.lines.first)
      let last = try #require(chapters.last?.lines.last)
      let firstID = "\(chapters[0].categoryID)-\(first.id)"
      let lastID = "\(chapters[chapters.count - 1].categoryID)-\(last.id)"
      #expect(firstID == "16-27")
      #expect(lastID == "25-73")
      print("16-27")
      print("25-73")
    }
  }

  @MainActor
  @Test func lineCountIs45() throws {
    let clock = ContinuousClock()
    let start = clock.now
    let english = try GuideCatalog.load(language: "en", repository: AzkarRepository())
    let arabic = try GuideCatalog.load(language: "ar", repository: AzkarRepository())
    let elapsed = clock.now - start
    #expect(english.reduce(0) { $0 + $1.lines.count } == 45)
    #expect(arabic.reduce(0) { $0 + $1.lines.count } == 45)
    #expect(elapsed < Duration.milliseconds(50))
    print("45 lines")
  }

  @MainActor
  @Test func repeatsFollowTheActiveLanguage() throws {
    let english = try GuideCatalog.load(language: "en", repository: AzkarRepository())
    let arabic = try GuideCatalog.load(language: "ar", repository: AzkarRepository())
    let english25 = try #require(english.first { $0.categoryID == 25 })
    let arabic25 = try #require(arabic.first { $0.categoryID == 25 })
    let english16 = try #require(english.first { $0.categoryID == 16 })
    let arabic16 = try #require(arabic.first { $0.categoryID == 16 })
    let english66 = try #require(english25.lines.first { $0.id == 66 })
    let arabic66 = try #require(arabic25.lines.first { $0.id == 66 })
    let english31 = try #require(english16.lines.first { $0.id == 31 })
    let arabic31 = try #require(arabic16.lines.first { $0.id == 31 })
    let english69 = try #require(english25.lines.first { $0.id == 69 })
    let arabic69 = try #require(arabic25.lines.first { $0.id == 69 })
    #expect(english66.repeatCount == 1)
    #expect(arabic66.repeatCount == 3)
    #expect(arabic31.repeatCount == 3)
    #expect(english31.repeatCount == 1)
    #expect(english69.repeatCount == 33)
    #expect(arabic69.repeatCount == 33)
    print("Arabic entry 66 repeats 3")
    print("English entry 66 repeats 1")
  }

  @MainActor
  @Test func posturesMatchCategories() throws {
    let chapters = try GuideCatalog.load(language: "en", repository: AzkarRepository())
    #expect(chapters.map(\.posture) == [
      "standing", "bowing", "standing", "prostrating", "sitting", "sitting", "sitting", "sitting",
      "after",
    ])
    print("category 17 posture bowing")
  }

  @MainActor
  @Test func onlyPostureChangesHaveEnterFrames() throws {
    let chapters = try GuideCatalog.load(language: "en", repository: AzkarRepository())
    #expect(try #require(chapters.first { $0.categoryID == 16 }).enterFrames.isEmpty)
    #expect(try #require(chapters.first { $0.categoryID == 17 }).enterFrames == ["GuideBow"])
    #expect(try #require(chapters.first { $0.categoryID == 18 }).enterFrames == ["GuideRise"])
    #expect(try #require(chapters.first { $0.categoryID == 19 }).enterFrames == ["GuideProstrate"])
    #expect(try #require(chapters.first { $0.categoryID == 20 }).enterFrames == ["GuideSit"])
    #expect(try #require(chapters.first { $0.categoryID == 22 }).enterFrames.isEmpty)
    #expect(try #require(chapters.first { $0.categoryID == 23 }).enterFrames.isEmpty)
    #expect(try #require(chapters.first { $0.categoryID == 24 }).enterFrames.isEmpty)
    #expect(try #require(chapters.first { $0.categoryID == 25 }).enterFrames == ["GuideAfter"])
  }
}
