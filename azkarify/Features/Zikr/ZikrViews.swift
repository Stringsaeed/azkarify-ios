import SwiftUI

struct ZikrListView: View {
  @AppStorage("accent") private var accent = "brown"
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
            AppCopy.text("Could not load azkar"),
            systemImage: "doc.text", description: Text(errorMessage))
          Button(AppCopy.text("Retry")) {
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
    .background(AppAppearance.background(accent))
    .appNavigationTitle(category.title, language: store.language)
    .toolbar {
      Button {
        showSlideshow = true
      } label: {
        Image(systemName: "slider.horizontal.below.rectangle")
      }
      .disabled(entries.isEmpty)
      .accessibilityLabel(AppCopy.text("Slideshow"))
    }
    .fullScreenCover(isPresented: $showSlideshow) {
      SlideshowView(entries: entries, title: category.title)
    }
    .task(id: category.detailUrl) { await load() }
  }

  private func load() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      entries = try store.repository.entries(for: category)
    } catch { errorMessage = error.localizedDescription }
  }
}

struct ZikrCard: View {
  @EnvironmentObject private var store: AzkarStore
  let entry: ZikrEntry
  @State private var showCounter = false
  private var text: String { store.language == "ar" ? entry.text.arabic : entry.text.translated }

  var body: some View {
    AppListItem(horizontalPadding: 14, verticalPadding: 12) {
      VStack(alignment: .leading, spacing: 12) {
        Text(text)
          .textSelection(.enabled)
          .font(
            AppAppearance.font(
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
                size: 21, relativeTo: .title3)
            )
            .frame(minHeight: 44)
          }
          .accessibilityLabel(
            AppCopy.format("Count down from %lld", entry.repeat))
        }
      }
    }
    .sheet(isPresented: $showCounter) { CounterView(initialCount: entry.repeat, title: text) }
  }
}

struct SlideshowView: View {
  @AppStorage("accent") private var accent = "brown"
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: AzkarStore
  let entries: [ZikrEntry]
  let title: String
  @State private var page = 0
  @State private var showCounter = false

  private var currentEntry: ZikrEntry? {
    entries.indices.contains(page) ? entries[page] : nil
  }

  private var currentText: String {
    guard let entry = currentEntry else { return "" }
    return store.language == "ar" ? entry.text.arabic : entry.text.translated
  }

  var body: some View {
    NavigationStack {
      TabView(selection: $page) {
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
          ScrollView {
            Text(store.language == "ar" ? entry.text.arabic : entry.text.translated)
              .textSelection(.enabled)
              .font(
                AppAppearance.font(
                  size: 30, relativeTo: .largeTitle)
              )
              .multilineTextAlignment(.center)
              .frame(maxWidth: .infinity)
              .padding(24)
              .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
              .padding(16)
          }
          .tag(index)
          .accessibilityLabel(
            AppCopy.format("Zikr %lld of %lld", index + 1, entries.count))
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .environment(\.layoutDirection, store.language == "ar" ? .rightToLeft : .leftToRight)
      .background(AppAppearance.background(accent))
      .appNavigationTitle(title, language: store.language)
      .toolbar {
        ToolbarItem(placement: store.language == "ar" ? .topBarLeading : .topBarTrailing) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
          }
          .accessibilityLabel(AppCopy.text("Close"))
        }
      }
      .safeAreaInset(edge: .bottom) {
        slideshowChrome
      }
      .sheet(isPresented: $showCounter) {
        CounterView(initialCount: currentEntry?.repeat ?? 0, title: currentText)
          .id(currentEntry?.id)
      }
    }
  }

  private var slideshowChrome: some View {
    VStack(spacing: 12) {
      ProgressView(value: Double(page + 1), total: Double(max(entries.count, 1)))
        .tint(AppAppearance.accent(accent))
        .accessibilityHidden(true)
      HStack(spacing: 12) {
        Text(AppCopy.format("Zikr %lld of %lld", page + 1, entries.count))
          .font(AppAppearance.font(size: 17, relativeTo: .headline, bold: true))
          .foregroundStyle(AppAppearance.accent(accent))
          .accessibilityIdentifier("slideshowProgress")
        Spacer(minLength: 0)
        if let entry = currentEntry, entry.repeat > 1 {
          Button {
            showCounter = true
          } label: {
            Label {
              Text("\(entry.repeat)")
            } icon: {
              Text("📿")
            }
            .font(AppAppearance.font(size: 21, relativeTo: .title3))
            .frame(minHeight: 44)
          }
          .accessibilityLabel(AppCopy.format("Count down from %lld", entry.repeat))
          .accessibilityIdentifier("slideshowCounter")
        }
      }
    }
    .padding(.horizontal, 24)
    .padding(.top, 12)
    .padding(.bottom, 8)
    .background(AppAppearance.background(accent))
  }
}
