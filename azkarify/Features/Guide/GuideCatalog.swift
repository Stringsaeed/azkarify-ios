import Foundation

struct GuideLine {
  let id: Int
  let repeatCount: Int
  let arabic: String
  let translated: String
}

struct GuideChapter {
  let categoryID: Int
  let posture: String
  let enterFrames: [String]
  let lines: [GuideLine]

  init(categoryID: Int, posture: String, enterFrames: [String], lines: [GuideLine] = []) {
    self.categoryID = categoryID
    self.posture = posture
    self.enterFrames = enterFrames
    self.lines = lines
  }
}

enum GuideCatalog {
  static let chapters: [GuideChapter] = [
    GuideChapter(categoryID: 16, posture: "standing", enterFrames: []),
    GuideChapter(categoryID: 17, posture: "bowing", enterFrames: ["GuideBow"]),
    GuideChapter(categoryID: 18, posture: "standing", enterFrames: ["GuideRise"]),
    GuideChapter(categoryID: 19, posture: "prostrating", enterFrames: ["GuideProstrate"]),
    GuideChapter(categoryID: 20, posture: "sitting", enterFrames: ["GuideSit"]),
    GuideChapter(categoryID: 22, posture: "sitting", enterFrames: []),
    GuideChapter(categoryID: 23, posture: "sitting", enterFrames: []),
    GuideChapter(categoryID: 24, posture: "sitting", enterFrames: []),
    GuideChapter(categoryID: 25, posture: "after", enterFrames: ["GuideAfter"]),
  ]

  @MainActor
  static func load(language: String, repository: AzkarRepository) throws -> [GuideChapter] {
    let categories = try repository.categories(language: language)
    return try chapters.map { chapter in
      guard let category = categories.first(where: { $0.id == chapter.categoryID }) else {
        throw CocoaError(.fileNoSuchFile)
      }
      let lines = try repository.entries(for: category).map { entry in
        GuideLine(
          id: entry.id,
          repeatCount: entry.repeat,
          arabic: entry.text.arabic,
          translated: entry.text.translated
        )
      }
      return GuideChapter(
        categoryID: chapter.categoryID,
        posture: chapter.posture,
        enterFrames: chapter.enterFrames,
        lines: lines
      )
    }
  }
}
