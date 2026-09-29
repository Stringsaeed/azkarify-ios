import Combine
import Foundation

@MainActor
final class AzkarStore: ObservableObject {
  let repository: AzkarRepository
  @Published var categories: [ZikrCategory] = []
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published var favorites: Set<Int> {
    didSet { UserDefaults.standard.set(Array(favorites), forKey: "favorites") }
  }
  @Published var language: String {
    didSet {
      UserDefaults.standard.set(language, forKey: "language")
      categories = []
    }
  }

  init(repository: AzkarRepository) {
    self.repository = repository
    favorites = Set(UserDefaults.standard.array(forKey: "favorites") as? [Int] ?? [])
    let deviceLanguage = Locale.preferredLanguages.first?.hasPrefix("ar") == true ? "ar" : "en"
    language = UserDefaults.standard.string(forKey: "language") ?? deviceLanguage
  }

  func load(refresh: Bool = false) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do { categories = try await repository.categories(language: language, refresh: refresh) } catch
    { errorMessage = error.localizedDescription }
  }

  func toggleFavorite(_ id: Int) {
    if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
  }
}
