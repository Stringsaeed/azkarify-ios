import SwiftUI

struct ZikrListView: View {
  @EnvironmentObject private var store: AzkarStore
  let category: ZikrCategory
  @State private var entries: [ZikrEntry] = []
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var showSlideshow = false

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        if isLoading && entries.isEmpty { ProgressView().padding() }
        if let errorMessage, entries.isEmpty {
          ContentUnavailableView(
            AppCopy.text("Could not load azkar", "تعذر تحميل الأذكار", language: store.language),
            systemImage: "wifi.exclamationmark", description: Text(errorMessage))
          Button(AppCopy.text("Retry", "إعادة المحاولة", language: store.language)) {
            Task { await load() }
          }
        }
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
          ZikrCard(entry: entry)
            .modifier(StaggeredEntrance(index: index))
        }
      }
      .padding(16)
    }
    .background(AppAppearance.background)
    .appNavigationTitle(category.title, language: store.language)
    .refreshable { await load(refresh: true) }
    .toolbar {
      Button {
        showSlideshow = true
      } label: {
        Image(systemName: "slider.horizontal.below.rectangle")
      }
      .disabled(entries.isEmpty)
      .accessibilityLabel(AppCopy.text("Slideshow", "عرض الشرائح", language: store.language))
    }
    .sheet(isPresented: $showSlideshow) { SlideshowView(entries: entries, title: category.title) }
    .task(id: category.detailUrl) { await load() }
  }

  private func load(refresh: Bool = false) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      entries = try await store.repository.entries(
        for: category, language: store.language, refresh: refresh)
    } catch { errorMessage = error.localizedDescription }
  }
}

struct ZikrCard: View {
  @EnvironmentObject private var store: AzkarStore
  @AppStorage("font") private var selectedFont = "ibmPlexSansArabic"
  let entry: ZikrEntry
  @State private var showCounter = false
  private var text: String { store.language == "ar" ? entry.text.arabic : entry.text.translated }

  var body: some View {
    AppListItem(horizontalPadding: 14, verticalPadding: 12) {
      VStack(alignment: .leading, spacing: 12) {
        Text(text)
          .font(
            AppAppearance.font(
              language: store.language, choice: selectedFont,
              size: store.language == "ar" ? 20 : 21, relativeTo: .title3)
          )
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityAddTraits(.isStaticText)
        if entry.repeat > 1 {
          Button {
            showCounter = true
          } label: {
            Label {
              Text("\(entry.repeat)")
            } icon: {
              Text("📿")
            }
            .font(
              AppAppearance.font(
                language: store.language, choice: selectedFont, size: 21, relativeTo: .title3)
            )
            .frame(minHeight: 44)
          }
          .accessibilityLabel(
            AppCopy.text(
              "Count down from \(entry.repeat)", "ابدأ العد من \(entry.repeat)",
              language: store.language))
        }
      }
    }
    .sheet(isPresented: $showCounter) { CounterView(initialCount: entry.repeat, title: text) }
  }
}

struct SlideshowView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: AzkarStore
  @AppStorage("font") private var selectedFont = "ibmPlexSansArabic"
  let entries: [ZikrEntry]
  let title: String
  @State private var page = 0

  var body: some View {
    NavigationStack {
      TabView(selection: $page) {
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
          ScrollView {
            Text(store.language == "ar" ? entry.text.arabic : entry.text.translated)
              .font(
                AppAppearance.font(
                  language: store.language, choice: selectedFont, size: 30, relativeTo: .largeTitle)
              )
              .multilineTextAlignment(.center)
              .frame(maxWidth: .infinity)
              .padding(24)
              .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
              .padding(16)
          }
          .tag(index)
          .accessibilityLabel(
            AppCopy.text(
              "Zikr \(index + 1) of \(entries.count)", "الذكر \(index + 1) من \(entries.count)",
              language: store.language))
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .automatic))
      .environment(\.layoutDirection, store.language == "ar" ? .rightToLeft : .leftToRight)
      .background(AppAppearance.background)
      .appNavigationTitle(title, language: store.language)
      .toolbar {
        ToolbarItem(placement: store.language == "ar" ? .topBarLeading : .topBarTrailing) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
          }
          .accessibilityLabel(AppCopy.text("Close", "إغلاق", language: store.language))
        }
      }
    }
  }
}
