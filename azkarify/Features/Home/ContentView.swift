import SPIndicator
import SwiftUI
import UIKit

private enum HomeRoute: Hashable {
  case favorites
  case counter
  case quickMode
}

struct ContentView: View {
  @EnvironmentObject private var store: AzkarStore
  @AppStorage("font") private var selectedFont = "ibmPlexSansArabic"
  @AppStorage("accent") private var accent = "brown"
  @State private var search = ""
  @State private var path = [HomeRoute]()
  @State private var showMenu = false

  private var results: [ZikrCategory] {
    guard !search.isEmpty else { return store.categories }
    return store.categories.filter { $0.title.localizedStandardContains(search) }
  }

  var body: some View {
    NavigationStack(path: $path) {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 12) {
          Text(
            AppCopy.text(
              "Find the right zikr faster", "ابحث عن الذكر المناسب", language: store.language)
          )
          .font(
            AppAppearance.font(
              language: store.language, choice: selectedFont, size: 25, relativeTo: .title2,
              bold: true))
          Text(AppCopy.text("All azkar", "جميع الأذكار", language: store.language))
            .font(
              AppAppearance.font(
                language: store.language, choice: selectedFont, size: 18, relativeTo: .headline,
                bold: true))
          if store.isLoading && store.categories.isEmpty {
            ProgressView().frame(maxWidth: .infinity).accessibilityLabel(
              AppCopy.text("Loading azkar", "جارٍ تحميل الأذكار", language: store.language))
          } else if let error = store.errorMessage, store.categories.isEmpty {
            ContentUnavailableView(
              AppCopy.text("Could not load azkar", "تعذر تحميل الأذكار", language: store.language),
              systemImage: "wifi.exclamationmark", description: Text(error))
            Button(AppCopy.text("Retry", "إعادة المحاولة", language: store.language)) {
              Task { await store.load() }
            }
          } else if results.isEmpty {
            ContentUnavailableView(
              AppCopy.text("No azkar found", "لم يُعثر على أذكار", language: store.language),
              systemImage: "magnifyingglass")
          }
          ForEach(Array(results.enumerated()), id: \.element.id) { index, category in
            CategoryRow(category: category)
              .modifier(StaggeredEntrance(index: index))
          }
        }
        .padding(16)
      }
      .background(AppAppearance.background)
      .appNavigationTitle(
        AppCopy.text("Husn", "حصن المسلم", language: store.language), language: store.language
      )
      .searchable(
        text: $search,
        prompt: AppCopy.text("Search azkar", "ابحث في الأذكار", language: store.language)
      )
      .refreshable { await store.load(refresh: true) }
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            showMenu = true
          } label: {
            Image(systemName: "line.3.horizontal")
          }
          .popover(isPresented: $showMenu) {
            VStack(alignment: .leading, spacing: 4) {
              menuButton(
                AppCopy.text("Favorites", "المفضلة", language: store.language),
                emoji: "⭐", route: .favorites)
              menuButton(
                AppCopy.text("Counter", "السبحة", language: store.language),
                emoji: "📿", route: .counter)
              menuButton(
                AppCopy.text("Quick Mode", "الوضع السريع", language: store.language),
                emoji: "⚡", route: .quickMode)
            }
            .padding(12)
            .frame(minWidth: 220)
            .background(AppAppearance.background)
            .presentationCompactAdaptation(.popover)
          }
          .foregroundStyle(AppAppearance.accent(accent))
          .accessibilityLabel(AppCopy.text("Menu", "القائمة", language: store.language))
        }
        ToolbarItem(placement: .topBarTrailing) {
          NavigationLink {
            SettingsView()
          } label: {
            Image(systemName: "gearshape")
          }
          .foregroundStyle(AppAppearance.accent(accent))
          .accessibilityLabel(AppCopy.text("Settings", "الإعدادات", language: store.language))
        }
      }
      .navigationDestination(for: HomeRoute.self) { route in
        switch route {
        case .favorites: FavoritesView()
        case .counter: CounterView()
        case .quickMode: QuickModeView()
        }
      }
      .task(id: store.language) { await store.load() }
    }
    .environment(\.layoutDirection, store.language == "ar" ? .rightToLeft : .leftToRight)
  }

  private func menuButton(
    _ title: String, emoji: String, route: HomeRoute
  ) -> some View {
    Button {
      showMenu = false
      path.append(route)
    } label: {
      HStack(spacing: 12) {
        Text(emoji).frame(width: 26).accessibilityHidden(true)
        Text(title)
          .font(AppAppearance.font(language: store.language, choice: selectedFont, size: 17))
        Spacer(minLength: 0)
      }
      .frame(minHeight: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(AppAppearance.accent(accent))
  }
}

struct CategoryRow: View {
  @EnvironmentObject private var store: AzkarStore
  @AppStorage("font") private var selectedFont = "ibmPlexSansArabic"
  @AppStorage("accent") private var accent = "brown"
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let category: ZikrCategory

  var body: some View {
    AppListItem(horizontalPadding: 12, verticalPadding: 6) {
      HStack(spacing: 8) {
        NavigationLink {
          ZikrListView(category: category)
        } label: {
          HStack(spacing: 8) {
            Text(ZikrEmoji.forCategory(category.id))
              .font(.system(size: 21))
              .frame(width: 26)
              .accessibilityHidden(true)
            Text(category.title)
              .font(AppAppearance.font(language: store.language, choice: selectedFont, size: 16))
              .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Image(systemName: "chevron.forward").font(.caption2)
              .foregroundStyle(AppAppearance.accent(accent))
              .accessibilityHidden(true)
          }
          .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .accessibilityLabel(category.title)
        .accessibilityHint(AppCopy.text("Open azkar", "افتح الأذكار", language: store.language))
        Button {
          let isAdding = !store.favorites.contains(category.id)
          withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
            store.toggleFavorite(category.id)
          }
          if isAdding {
            let title = AppCopy.text(
              "Zikr added to favourites", "أُضيف الذكر إلى المفضلة", language: store.language)
            SPIndicatorView(title: title, preset: .done).present()
            UIAccessibility.post(notification: .announcement, argument: title)
          }
        } label: {
          Image(systemName: store.favorites.contains(category.id) ? "star.fill" : "star")
            .contentTransition(.symbolEffect(.replace))
            .foregroundStyle(AppAppearance.accent(accent))
            .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(
          store.favorites.contains(category.id)
            ? AppCopy.text("Remove from favorites", "إزالة من المفضلة", language: store.language)
            : AppCopy.text("Add to favorites", "إضافة إلى المفضلة", language: store.language))
      }
      .foregroundStyle(.primary)
    }
  }
}
