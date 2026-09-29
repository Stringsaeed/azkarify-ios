import Foundation
import SwiftData

@MainActor
final class AzkarRepository {
  private let context: ModelContext
  private let baseURL = URL(
    string: "https://cdn.jsdelivr.net/gh/Stringsaeed/azkarify-husn-cdn@v2/v1")!

  init(context: ModelContext) { self.context = context }

  func categories(language: String, refresh: Bool = false) async throws -> [ZikrCategory] {
    let key = "index:\(language)"
    let data = try await document(
      key: key, path: "/\(language)/husn_\(language).json", refresh: refresh)
    return try JSONDecoder().decode(ZikrIndex.self, from: data).items
  }

  func entries(for category: ZikrCategory, language: String, refresh: Bool = false) async throws
    -> [ZikrEntry]
  {
    let key = "details:\(language):\(category.id)"
    let data = try await document(key: key, path: category.detailUrl, refresh: refresh)
    return try JSONDecoder().decode(ZikrDetails.self, from: data).items
  }

  private func document(key: String, path: String, refresh: Bool) async throws -> Data {
    let descriptor = FetchDescriptor<CachedAzkarDocument>(predicate: #Predicate { $0.key == key })
    let cached = try context.fetch(descriptor).first
    if let cached, !refresh { return cached.json }

    let url = baseURL.appendingPathComponent(
      path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode)
      else {
        throw URLError(.badServerResponse)
      }
      let clean = data.starts(with: [0xEF, 0xBB, 0xBF]) ? Data(data.dropFirst(3)) : data
      if let cached {
        cached.json = clean
      } else {
        context.insert(CachedAzkarDocument(key: key, json: clean))
      }
      try context.save()
      return clean
    } catch {
      if let cached { return cached.json }
      throw error
    }
  }
}
