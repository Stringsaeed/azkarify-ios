import SwiftUI

struct FavoritesView: View {
  @EnvironmentObject private var store: AzkarStore
  var body: some View {
    ScrollView {
      LazyVStack(spacing: 16) {
        let items = store.categories.filter { store.favorites.contains($0.id) }
        if items.isEmpty {
          ContentUnavailableView(
            AppCopy.text("No favorites yet"),
            systemImage: "star")
        }
        ForEach(items) { CategoryRow(category: $0) }
      }.padding(16)
    }
    .background(AppAppearance.background)
    .appNavigationTitle(
      AppCopy.text("Favorites"), language: store.language)
  }
}
