import Foundation

@MainActor
final class AzkarRepository {
  private let bundle: Bundle

  init(bundle: Bundle = .main) { self.bundle = bundle }

  func categories(language: String) throws -> [ZikrCategory] {
    let data = try document(path: "/\(language)/husn_\(language).json")
    return try JSONDecoder().decode(ZikrIndex.self, from: data).items
  }

  func entries(for category: ZikrCategory) throws -> [ZikrEntry] {
    let data = try document(path: category.detailUrl)
    return try JSONDecoder().decode(ZikrDetails.self, from: data).items
  }

  private func document(path: String) throws -> Data {
    let relativePath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    guard let url = bundle.url(forResource: relativePath, withExtension: nil, subdirectory: "content")
    else { throw CocoaError(.fileNoSuchFile) }
    return try Data(contentsOf: url)
  }
}
