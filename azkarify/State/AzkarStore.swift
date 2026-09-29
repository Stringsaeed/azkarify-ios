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
  var language: String {
    Bundle.main.preferredLocalizations.first?.hasPrefix("ar") == true ? "ar" : "en"
  }

  init(repository: AzkarRepository) {
    self.repository = repository
    favorites = Set(UserDefaults.standard.array(forKey: "favorites") as? [Int] ?? [])
  }

  func load() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do { categories = try repository.categories(language: language) } catch
    { errorMessage = error.localizedDescription }
  }

  func toggleFavorite(_ id: Int) {
    if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
  }
}
