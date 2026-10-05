import Foundation
import SwiftUI
import Testing
import UIKit

@testable import azkarify

struct azkarifyTests {
  @MainActor
  @Test func nativeSearchFieldUsesAppFont() async throws {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 834, height: 1194))
    let host = UIHostingController(
      rootView: ContentView()
        .environmentObject(AzkarStore(repository: AzkarRepository()))
        .environmentObject(PrayerScheduleStore())
        .environmentObject(JourneyProgressStore())
        .environmentObject(LocationCatalogStore()))
    window.rootViewController = host
    window.makeKeyAndVisible()
    defer { window.isHidden = true }

    func searchField(in view: UIView) -> UISearchTextField? {
      if let field = view as? UISearchTextField { return field }
      return view.subviews.lazy.compactMap { searchField(in: $0) }.first
    }

    for _ in 0..<20 where searchField(in: host.view) == nil {
      try await Task.sleep(for: .milliseconds(100))
      host.view.layoutIfNeeded()
    }
    let field = try #require(searchField(in: host.view))
    for _ in 0..<20 where field.font?.familyName != "Alan Sans" {
      try await Task.sleep(for: .milliseconds(100))
      host.view.layoutIfNeeded()
    }
    #expect(field.font?.familyName == "Alan Sans")
    if let placeholder = field.attributedPlaceholder, placeholder.length > 0 {
      let font = placeholder.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
      #expect(font?.familyName == "Alan Sans")
    }

    let originalSize = try #require(field.font?.pointSize)
    host.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
    for _ in 0..<20 where (field.font?.pointSize ?? 0) <= originalSize {
      try await Task.sleep(for: .milliseconds(100))
      host.view.layoutIfNeeded()
    }
    #expect(field.font?.familyName == "Alan Sans")
    #expect((field.font?.pointSize ?? 0) > originalSize)
  }

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

  @Test func slideshowFinishedOnlyOnLastUnreadPage() {
    #expect(Celebration.slideshowFinished(page: 0, entryCount: 24, alreadyCelebrated: false) == false)
    #expect(Celebration.slideshowFinished(page: 23, entryCount: 24, alreadyCelebrated: false))
    #expect(Celebration.slideshowFinished(page: 23, entryCount: 24, alreadyCelebrated: true) == false)
    #expect(Celebration.slideshowFinished(page: 0, entryCount: 1, alreadyCelebrated: false))
    #expect(Celebration.slideshowFinished(page: 0, entryCount: 0, alreadyCelebrated: false) == false)
  }

  @Test func slideshowProgressAndConfettiOnlyForSetsLargerThanThree() {
    #expect(Celebration.showsSlideshowProgress(entryCount: 0) == false)
    #expect(Celebration.showsSlideshowProgress(entryCount: 3) == false)
    #expect(Celebration.showsSlideshowProgress(entryCount: 4))
    #expect(Celebration.celebratesSlideshow(page: 2, entryCount: 3, alreadyCelebrated: false) == false)
    #expect(Celebration.celebratesSlideshow(page: 3, entryCount: 4, alreadyCelebrated: false))
    #expect(Celebration.celebratesSlideshow(page: 0, entryCount: 4, alreadyCelebrated: false) == false)
  }
}
