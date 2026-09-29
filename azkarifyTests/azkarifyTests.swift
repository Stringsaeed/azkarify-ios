import Foundation
import SwiftData
import Testing

@testable import azkarify

struct azkarifyTests {
  @MainActor
  @Test func cachedIndexLoadsWithoutNetwork() async throws {
    let container = try ModelContainer(
      for: CachedAzkarDocument.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let json = Data(
      #"{"items":[{"audioUrl":"","detailUrl":"/en/27.json","id":27,"title":"Morning and evening"}]}"#
        .utf8)
    container.mainContext.insert(CachedAzkarDocument(key: "index:en", json: json))
    try container.mainContext.save()

    let categories = try await AzkarRepository(context: container.mainContext).categories(
      language: "en")
    #expect(categories.map(\.title) == ["Morning and evening"])
  }

  @MainActor
  @Test func cachedEntriesAreSeparateByLanguage() async throws {
    let container = try ModelContainer(
      for: CachedAzkarDocument.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let json = Data(
      #"{"items":[{"audioUrl":"","id":75,"repeat":3,"text":{"arabic":"ذكر","arabicTranslated":"dhikr","translated":"Remembrance"}}]}"#
        .utf8)
    container.mainContext.insert(CachedAzkarDocument(key: "details:ar:27", json: json))
    try container.mainContext.save()

    let category = ZikrCategory(
      audioUrl: "", detailUrl: "/ar/27.json", id: 27, title: "أذكار الصباح")
    let entries = try await AzkarRepository(context: container.mainContext).entries(
      for: category, language: "ar")
    #expect(entries.first?.repeat == 3)
    #expect(entries.first?.text.arabic == "ذكر")
  }
}
