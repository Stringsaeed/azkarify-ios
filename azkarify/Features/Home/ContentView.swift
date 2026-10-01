import SPIndicator
import SwiftUI
import UIKit

private enum HomeRoute: Hashable {
  case category(Int)
  case settings
  case favorites
  case counter
  case quickMode
}

struct ContentView: View {
  @EnvironmentObject private var store: AzkarStore
  @AppStorage("accent") private var accent = "brown"
  @State private var search = ""
  @State private var selection: HomeRoute?
  @State private var preferredColumn: NavigationSplitViewColumn = .sidebar
  @State private var showMenu = false

  private var results: [ZikrCategory] {
    guard !search.isEmpty else { return store.categories }
    return store.categories.filter { $0.title.localizedStandardContains(search) }
  }

  var body: some View {
    NavigationSplitView(preferredCompactColumn: $preferredColumn) {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 12) {
          Text(
            AppCopy.text("Find the right zikr faster")
          )
          .font(
            AppAppearance.font(
              size: 25, relativeTo: .title2,
              bold: true))
          Text(AppCopy.text("All azkar"))
            .font(
              AppAppearance.font(
                size: 18, relativeTo: .headline,
                bold: true))
          if store.isLoading && store.categories.isEmpty {
            ProgressView().frame(maxWidth: .infinity).accessibilityLabel(
              AppCopy.text("Loading azkar"))
          } else if let error = store.errorMessage, store.categories.isEmpty {
            ContentUnavailableView(
              AppCopy.text("Could not load azkar"),
              systemImage: "doc.text", description: Text(error))
            Button(AppCopy.text("Retry")) {
              Task { await store.load() }
            }
          } else if results.isEmpty {
            ContentUnavailableView(
              AppCopy.text("No azkar found"),
              systemImage: "magnifyingglass")
          }
          ForEach(Array(results.enumerated()), id: \.element.id) { index, category in
            CategoryRow(
              category: category,
              isSelected: selection == .category(category.id),
              onSelect: { select(.category(category.id)) }
            )
            .modifier(StaggeredEntrance(index: index))
          }
        }
        .padding(16)
      }
      .background(AppAppearance.background(accent))
      .overlay(alignment: .bottom) {
        LinearGradient(
          stops: (0...12).map { index in
            let progress = Double(index) / 12
            let opacity = progress * progress * (3 - 2 * progress)
            return .init(
              color: AppAppearance.background(accent).opacity(opacity), location: CGFloat(progress))
          },
          startPoint: .top,
          endPoint: .bottom
        )
        .frame(height: 120)
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
      }
      .appNavigationTitle(
        AppCopy.text("Husn"), language: store.language
      )
      .searchable(
        text: $search,
        prompt: AppCopy.text("Search azkar")
      )
      .background(SearchFieldTypography().allowsHitTesting(false))
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
                AppCopy.text("Favorites"),
                emoji: "⭐", route: .favorites)
              menuButton(
                AppCopy.text("Counter"),
                emoji: "📿", route: .counter)
              menuButton(
                AppCopy.text("Quick Mode"),
                emoji: "⚡", route: .quickMode)
            }
            .padding(12)
            .frame(minWidth: 220)
            .background(AppAppearance.background(accent))
            .presentationCompactAdaptation(.popover)
          }
          .foregroundStyle(AppAppearance.accent(accent))
          .accessibilityLabel(AppCopy.text("Menu"))
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            select(.settings)
          } label: {
            Image(systemName: "gearshape")
          }
          .foregroundStyle(AppAppearance.accent(accent))
          .accessibilityLabel(AppCopy.text("Settings"))
        }
      }
      .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 400)
      .accessibilityIdentifier("azkarSidebar")
    } detail: {
      NavigationStack {
        detail
      }
      .id(selection)
      .accessibilityIdentifier("azkarDetail")
    }
    .navigationSplitViewStyle(.balanced)
    .task(id: store.language) { await store.load() }
    .environment(\.layoutDirection, store.language == "ar" ? .rightToLeft : .leftToRight)
  }

  @ViewBuilder
  private var detail: some View {
    switch selection {
    case .category(let id):
      if let category = store.categories.first(where: { $0.id == id }) {
        ZikrListView(category: category)
          .id(category.detailUrl)
      }
    case .settings: SettingsView()
    case .favorites: FavoritesView()
    case .counter: CounterView()
    case .quickMode: QuickModeView()
    case nil:
      ContentUnavailableView(
        AppCopy.text("All azkar"), systemImage: "book.closed",
        description: Text(AppCopy.text("Find the right zikr faster"))
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(AppAppearance.background(accent))
    }
  }

  private func select(_ route: HomeRoute) {
    selection = route
    preferredColumn = .detail
  }

  private func menuButton(
    _ title: String, emoji: String, route: HomeRoute
  ) -> some View {
    Button {
      showMenu = false
      select(route)
    } label: {
      HStack(spacing: 12) {
        Text(emoji).frame(width: 26).accessibilityHidden(true)
        Text(title)
          .font(AppAppearance.font(size: 17))
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
  @AppStorage("accent") private var accent = "brown"
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let category: ZikrCategory
  var isSelected = false
  var onSelect: (() -> Void)?

  var body: some View {
    AppListItem(horizontalPadding: 12, verticalPadding: 6) {
      HStack(spacing: 8) {
        Group {
          if let onSelect {
            Button(action: onSelect) { categoryLabel }
              .buttonStyle(.plain)
              .accessibilityAddTraits(isSelected ? .isSelected : [])
          } else {
            NavigationLink {
              ZikrListView(category: category)
            } label: {
              categoryLabel
            }
          }
        }
        .accessibilityLabel(category.title)
        .accessibilityHint(AppCopy.text("Open azkar"))
        Button {
          let isAdding = !store.favorites.contains(category.id)
          withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
            store.toggleFavorite(category.id)
          }
          if isAdding {
            let title = AppCopy.text("Zikr added to favourites")
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
            ? AppCopy.text("Remove from favorites")
            : AppCopy.text("Add to favorites"))
      }
      .foregroundStyle(.primary)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .strokeBorder(AppAppearance.accent(accent).opacity(isSelected ? 0.65 : 0), lineWidth: 2)
        .allowsHitTesting(false)
    }
  }

  private var categoryLabel: some View {
    HStack(spacing: 8) {
      Text(ZikrEmoji.forCategory(category.id))
        .font(.system(size: 21))
        .frame(width: 26)
        .accessibilityHidden(true)
      Text(category.title)
        .font(AppAppearance.font(size: 16))
        .multilineTextAlignment(.leading)
      Spacer(minLength: 8)
      Image(systemName: "chevron.forward").font(.caption2)
        .foregroundStyle(AppAppearance.accent(accent))
        .accessibilityHidden(true)
    }
    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
  }
}
