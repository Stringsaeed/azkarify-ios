import SwiftUI
import UIKit

/// The Azkar tab: search, Quick start, All / Favourites and the full Hisn, list + detail on iPad.
struct AzkarTab: View {
  @EnvironmentObject private var store: AzkarStore
  @State private var selection: Int?
  @State private var preferredColumn: NavigationSplitViewColumn = .sidebar

  var body: some View {
    NavigationSplitView(preferredCompactColumn: $preferredColumn) {
      AzkarListView(selection: $selection)
        .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 440)
    } detail: {
      NavigationStack {
        Group {
          if let id = selection, let category = store.categories.first(where: { $0.id == id }) {
            ZikrListView(category: category).id(category.id)
          } else {
            AZEmptyState(
              title: AZLocale.text("Choose a zikr", "اختر ذكراً"),
              message: AZLocale.text("Pick a topic from the list to start reading.", "اختر باباً من القائمة لتبدأ القراءة.")
            ) {
              AZOrnament(shape: .star, size: 56, color: AZColor.spark)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .azScreenBackground()
          }
        }
        .navigationDestination(for: DetailRoute.self) { $0.destination }
      }
      .accessibilityIdentifier("azkarDetail")
    }
    .navigationSplitViewStyle(.balanced)
    .onChange(of: selection) { _, id in
      if id != nil { preferredColumn = .detail }
    }
  }
}

private enum AzkarFilter: Hashable {
  case all, favourites
}

struct AzkarListView: View {
  @EnvironmentObject private var store: AzkarStore
  @Binding var selection: Int?
  @State private var search = ""
  @State private var filter = AzkarFilter.all
  @State private var quickStart: ZikrCategory?

  private static let quickStartIDs: [(id: Int, symbol: String)] = [
    (27, "sun.horizon"), (28, "moon.stars"), (1, "sunrise"),
  ]

  private var results: [ZikrCategory] {
    var items = store.categories
    if filter == .favourites { items = items.filter { store.favorites.contains($0.id) } }
    guard !search.isEmpty else { return items }
    return items.filter { $0.title.localizedStandardContains(search) }
  }

  var body: some View {
    List(selection: $selection) {
      if search.isEmpty {
        Section {
          quickStartRow
        } header: {
          Text(AZLocale.text("Quick start", "ابدأ سريعاً")).azText(.eyebrow).foregroundStyle(AZColor.sparkInk)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)

        Section {
          Picker(AZLocale.text("Show", "عرض"), selection: $filter) {
            Text(AZLocale.text("All \(store.categories.count)",
                               "الكل \(AZLocale.number(store.categories.count))")).tag(AzkarFilter.all)
            Text(AZLocale.text("Favourites \(store.favorites.count)",
                               "المفضلة \(AZLocale.number(store.favorites.count))")).tag(AzkarFilter.favourites)
          }
          .pickerStyle(.segmented)
          .accessibilityIdentifier("azkar.filter")
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
      }

      Section {
        if store.isLoading && store.categories.isEmpty {
          ProgressView()
            .frame(maxWidth: .infinity)
            .accessibilityLabel(AZLocale.text("Loading azkar", "جارٍ تحميل الأذكار"))
            .listRowBackground(Color.clear)
        } else if let error = store.errorMessage, store.categories.isEmpty {
          AZEmptyState(title: AZLocale.text("Could not load azkar", "تعذر تحميل الأذكار"), message: error) {
            AZOrnament(shape: .crescent, size: 56, color: AZColor.clay)
          } actions: {
            Button(AZLocale.text("Retry", "إعادة المحاولة")) { Task { await store.load() } }
              .buttonStyle(.azSecondary)
          }
          .listRowBackground(Color.clear)
        } else if results.isEmpty {
          emptyState.listRowBackground(Color.clear)
        } else {
          ForEach(results) { category in
            CategoryRow(category: category)
              .tag(category.id)
              .listRowBackground(
                selection == category.id
                  ? AnyView(ZStack { AZColor.paperRaised; Rectangle().fill(.tint.opacity(0.1)) })
                  : AnyView(AZColor.paperRaised))
              .listRowInsets(EdgeInsets(top: 0, leading: AZSpace.md, bottom: 0, trailing: 4))
              .listRowSeparatorTint(AZColor.line)
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .listSectionSpacing(AZSpace.md)
    .azFormStyle()
    .navigationTitle(AZLocale.text("Azkar", "الأذكار"))
    .searchable(text: $search, prompt: AZLocale.text("Search azkar", "ابحث في الأذكار"))
    .background(SearchFieldTypography().allowsHitTesting(false))
    .fullScreenCover(item: $quickStart) { FocusModeLoader(category: $0) }
    .accessibilityIdentifier("azkarSidebar")
  }

  private var quickStartRow: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: AZSpace.xs) {
        ForEach(Self.quickStartIDs, id: \.id) { item in
          if let category = store.categories.first(where: { $0.id == item.id }) {
            AZChip(title: quickStartTitle(item.id), systemImage: item.symbol) { quickStart = category }
              .accessibilityIdentifier("quickStart-\(item.id)")
          }
        }
      }
      .padding(.horizontal, AZSpace.gutter)
    }
    .padding(.horizontal, -AZSpace.gutter)
    .scrollClipDisabled()
  }

  private func quickStartTitle(_ id: Int) -> String {
    switch id {
    case 27: AZLocale.text("Morning & Evening", "الصباح والمساء")
    case 28: AZLocale.text("Before Sleep", "قبل النوم")
    default: AZLocale.text("Upon Waking", "عند الاستيقاظ")
    }
  }

  @ViewBuilder private var emptyState: some View {
    if filter == .favourites && search.isEmpty {
      AZEmptyState(
        title: AZLocale.text("No favourites yet", "لا توجد مفضلة بعد"),
        message: AZLocale.text("Tap the star on any zikr to keep it here.", "انقر على النجمة بجانب أي ذكر لتحفظه هنا.")
      ) {
        AZOrnament(shape: .crescent, size: 56, color: AZColor.clay)
      }
    } else {
      AZEmptyState(title: AZLocale.text("No azkar found", "لم يُعثر على أذكار")) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 40))
          .foregroundStyle(AZColor.inkSubtle)
          .accessibilityHidden(true)
      }
    }
  }
}

/// One Hisn category: icon well, title and a favourite star beside (never inside) the link.
struct CategoryRow: View {
  @EnvironmentObject private var store: AzkarStore
  let category: ZikrCategory

  private var isFavourite: Bool { store.favorites.contains(category.id) }

  var body: some View {
    HStack(spacing: AZSpace.sm) {
      AZIconWell(systemImage: CategorySymbol.forCategory(category.id), size: 36)
      Text(category.title)
        .azText(.rowTitle)
        .foregroundStyle(AZColor.ink)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
      Button {
        let adding = !isFavourite
        withAnimation(AZMotion.curve(AZDuration.fast)) { store.toggleFavorite(category.id) }
        UIAccessibility.post(
          notification: .announcement,
          argument: adding
            ? AZLocale.text("Added to favourites", "أُضيف إلى المفضلة")
            : AZLocale.text("Removed from favourites", "أُزيل من المفضلة"))
      } label: {
        Image(systemName: isFavourite ? "star.fill" : "star")
          .font(.system(size: 18))
          .contentTransition(.symbolEffect(.replace))
          .foregroundStyle(.tint)
          .frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.borderless)
      .sensoryFeedback(.impact(weight: .light), trigger: isFavourite)
      .accessibilityLabel(isFavourite
                          ? AZLocale.text("Remove from favourites", "إزالة من المفضلة")
                          : AZLocale.text("Add to favourites", "إضافة إلى المفضلة"))
    }
    .frame(minHeight: 56)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("category-\(category.id)")
  }
}
