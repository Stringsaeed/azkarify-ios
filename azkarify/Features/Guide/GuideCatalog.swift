import Foundation

struct GuideBeat: Equatable {
  let categoryID: Int
  let entryID: Int
  let repeatCount: Int
  let posture: String
  let kidsLine: String?
}

enum GuideCatalog {
  static let sequence: [(categoryID: Int, posture: String)] = [
    (16, "GuideStanding"),
    (17, "JourneyCrescent"),
    (18, "GuideStanding"),
    (19, "GuideProstrating"),
    (20, "GuideSitting"),
    (22, "GuideSitting"),
    (23, "GuideSitting"),
    (24, "GuideSitting"),
    (25, "GuideAfter"),
  ]

  @MainActor
  static func beats(language: String, repository: AzkarRepository) throws -> [GuideBeat] {
    let categories = try repository.categories(language: language)
    let byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    var beats: [GuideBeat] = []
    for step in sequence {
      guard let category = byID[step.categoryID] else {
        throw CocoaError(.fileNoSuchFile)
      }
      let entries = try repository.entries(for: category)
      for entry in entries {
        beats.append(
          GuideBeat(
            categoryID: step.categoryID,
            entryID: entry.id,
            repeatCount: entry.repeat,
            posture: step.posture,
            kidsLine: nil
          )
        )
      }
    }
    return beats
  }
}
