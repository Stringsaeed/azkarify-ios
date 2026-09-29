import Foundation
import Testing

@testable import azkarify

struct azkarifyTests {
  @MainActor
  @Test(arguments: ["ar", "en"])
  func allBundledCategoriesAndEntriesLoad(language: String) throws {
    let repository = AzkarRepository()
    let categories = try repository.categories(language: language)
    #expect(categories.count == 132)
    #expect(Set(categories.map(\.id)).count == 132)
    var entryCount = 0
    for category in categories {
      let entries = try repository.entries(for: category)
      #expect(!entries.isEmpty)
      #expect(entries.allSatisfy { $0.repeat > 0 })
      entryCount += entries.count
    }
    #expect(entryCount == 267)
  }

  @MainActor
  @Test func editedArabicTextPreservesLineBreaksAndCounts() throws {
    let repository = AzkarRepository()
    let categories = try repository.categories(language: "ar")
    let morning = try #require(categories.first { $0.id == 27 })
    let entries = try repository.entries(for: morning)
    let first = try #require(entries.first { $0.id == 75 })
    #expect(first.text.arabic.hasPrefix("أَعُوذُ بِاللَّهِ مِنَ الشَّيطَانِ الرَّجِيمِ\n﴿اللَّهُ"))
    #expect(entries.first { $0.id == 83 }?.repeat == 7)
  }

  @MainActor
  @Test func collectionsRemainSeparate() throws {
    let repository = AzkarRepository()
    let arabic = try #require(repository.categories(language: "ar").first { $0.id == 27 })
    let english = try #require(repository.categories(language: "en").first { $0.id == 27 })
    #expect(arabic.title == "أذكار الصباح والمساء")
    #expect(english.title == "Words of remembrance for morning and evening")
    let arabicEntry = try #require(repository.entries(for: arabic).first { $0.id == 83 })
    let englishEntry = try #require(repository.entries(for: english).first { $0.id == 83 })
    #expect(arabicEntry.repeat == 7)
    #expect(englishEntry.repeat == 1)
    #expect(!englishEntry.text.translated.isEmpty)
  }

  @MainActor
  @Test func missingBundledFileThrows() {
    #expect(throws: CocoaError.self) {
      try AzkarRepository().categories(language: "missing")
    }
  }
}
