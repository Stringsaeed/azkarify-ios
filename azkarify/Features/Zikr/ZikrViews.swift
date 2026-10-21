import SwiftUI
import UIKit

/// The reader: one category's azkar as calm cards, with a progress line and focus mode.
struct ZikrListView: View {
  @EnvironmentObject private var store: AzkarStore
  @EnvironmentObject private var progress: JourneyProgressStore
  @AppStorage(ReaderSettings.scaleKey) private var scale = 1.0
  @AppStorage(ReaderSettings.transliterationKey) private var showsTransliteration = false
  let category: ZikrCategory
  @State private var entries: [ZikrEntry] = []
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var showFocusMode = false
  @State private var didFinishFocus = false
  @State private var visibleID: Int?
  @State private var counterEntry: ZikrEntry?
  @State private var completion: CompletionSummary?

  private var visibleIndex: Int {
    entries.firstIndex { $0.id == visibleID } ?? 0
  }

  var body: some View {
    ScrollView {
      LazyVStack(spacing: AZSpace.md) {
        if isLoading && entries.isEmpty { ProgressView().padding() }
        if let errorMessage, entries.isEmpty {
          AZEmptyState(title: AZLocale.text("Could not load azkar", "تعذر تحميل الأذكار"), message: errorMessage) {
            AZOrnament(shape: .crescent, size: 56, color: AZColor.clay)
          } actions: {
            Button(AZLocale.text("Retry", "إعادة المحاولة")) { Task { await load() } }
              .buttonStyle(.azSecondary)
          }
        }
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
          ZikrCard(
            entry: entry, index: index, total: entries.count, scale: scale,
            showsTransliteration: showsTransliteration
          ) { counterEntry = entry }
          .id(entry.id)
        }
      }
      .scrollTargetLayout()
      .padding(.horizontal, AZSpace.gutter)
      .padding(.top, AZSpace.xs)
      .padding(.bottom, AZSpace.xxl)
      .frame(maxWidth: 640)
      .frame(maxWidth: .infinity)
    }
    .scrollPosition(id: $visibleID, anchor: .top)
    .safeAreaInset(edge: .top, spacing: 0) {
      if entries.count > 1 {
        HStack(spacing: AZSpace.sm) {
          AZProgressTrack(value: Double(visibleIndex + 1) / Double(entries.count), height: 6)
          Text(AZLocale.position(visibleIndex + 1, of: entries.count))
            .azText(.footnote)
            .monospacedDigit()
            .foregroundStyle(AZColor.inkMuted)
            .accessibilityIdentifier("reader.position")
        }
        .padding(.horizontal, AZSpace.gutter)
        .padding(.vertical, AZSpace.xs)
        .background(AZColor.paper)
        .accessibilityElement(children: .combine)
      }
    }
    .azScreenBackground()
    .navigationTitle(category.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        ReaderSizeMenu()
        Button {
          UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
          didFinishFocus = false
          showFocusMode = true
        } label: {
          Image(systemName: "rectangle.portrait.on.rectangle.portrait")
        }
        .disabled(entries.isEmpty)
        .accessibilityLabel(AZLocale.text("Focus mode", "وضع التركيز"))
        .accessibilityIdentifier("focusMode")
      }
    }
    .fullScreenCover(isPresented: $showFocusMode, onDismiss: finishFocus) {
      FocusModeView(entries: entries, title: category.title) { didFinishFocus = true }
    }
    .sheet(item: $counterEntry) { entry in
      CounterView(initialCount: entry.repeat, title: entry.text.arabic)
    }
    .sheet(item: $completion) { CompletionSheet(summary: $0) }
    .task(id: category.detailUrl) { await load() }
  }

  private func finishFocus() {
    guard didFinishFocus else { return }
    didFinishFocus = false
    let before = progress.totalPoints
    let awarded = progress.completeSlideshow(categoryID: category.id)
    completion = CompletionSummary(
      stickerLabel: AZLocale.text("All read", "اكتملت القراءة"),
      title: category.title,
      message: AZLocale.text("Every zikr in this set, done.", "أتممت كل أذكار هذا الباب."),
      pointsEarned: awarded ? progress.totalPoints - before : 0,
      totalPoints: progress.totalPoints)
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

/// Focus mode: one zikr at a time, large and centred.
struct FocusModeView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage(ReaderSettings.scaleKey) private var scale = 1.0
  @AppStorage(ReaderSettings.transliterationKey) private var showsTransliteration = false
  let entries: [ZikrEntry]
  let title: String
  let onComplete: () -> Void
  @State private var page = 0
  @State private var counterEntry: ZikrEntry?

  private var currentEntry: ZikrEntry? {
    entries.indices.contains(page) ? entries[page] : nil
  }

  private var isLast: Bool { page == entries.count - 1 }

  var body: some View {
    VStack(spacing: 0) {
      header
      TabView(selection: $page) {
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
          ScrollView {
            pageContent(for: entry)
              .frame(maxWidth: 640)
              .frame(maxWidth: .infinity, minHeight: 0)
              .padding(.horizontal, 28)
              .padding(.vertical, AZSpace.xl)
          }
          .scrollBounceBehavior(.basedOnSize)
          .defaultScrollAnchor(.center, for: .alignment)
          .defaultScrollAnchor(.top, for: .initialOffset)
          .tag(index)
          .accessibilityLabel(AZLocale.text(
            "Zikr \(index + 1) of \(entries.count)",
            "الذكر \(AZLocale.number(index + 1)) من \(AZLocale.number(entries.count))"))
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      if !entries.isEmpty { footer }
    }
    .foregroundStyle(AZColor.ink)
    .azScreenBackground()
    .sheet(item: $counterEntry) { entry in
      CounterView(initialCount: entry.repeat, title: entry.text.arabic)
    }
  }

  private var header: some View {
    HStack(spacing: AZSpace.xs) {
      Button { dismiss() } label: { Image(systemName: "xmark") }
        .buttonStyle(.azIcon(.filled))
        .accessibilityLabel(AZLocale.text("Close", "إغلاق"))
        .accessibilityIdentifier("focus.close")
      VStack(spacing: 2) {
        Text(title).azText(.eyebrow).foregroundStyle(AZColor.sparkInk).lineLimit(1)
        if Celebration.showsSlideshowProgress(entryCount: entries.count) {
          Text(AZLocale.position(page + 1, of: entries.count))
            .azText(.footnote)
            .monospacedDigit()
            .foregroundStyle(AZColor.inkMuted)
            .accessibilityIdentifier("slideshowProgress")
        }
      }
      .frame(maxWidth: .infinity)
      ReaderSizeMenu()
        .foregroundStyle(AZColor.ink)
        .frame(width: 44, height: 44)
        .background(AZColor.paperSunk, in: Circle())
    }
    .padding(.horizontal, AZSpace.md)
    .padding(.top, AZSpace.xs)
  }

  private func pageContent(for entry: ZikrEntry) -> some View {
    VStack(spacing: AZSpace.xl) {
      Text(entry.text.arabic)
        .azReadingArabic(scale: scale * 1.5)
        .multilineTextAlignment(.center)
        .environment(\.layoutDirection, .rightToLeft)
        .textSelection(.enabled)
      if showsTransliteration && !entry.text.arabicTranslated.isEmpty {
        Text(entry.text.arabicTranslated)
          .azText(.callout)
          .italic()
          .foregroundStyle(AZColor.inkMuted)
          .multilineTextAlignment(.center)
      }
      if !AZLocale.isArabic && !entry.text.translated.isEmpty {
        Text(entry.text.translated)
          .azReadingTranslation(scale: scale * 20.0 / 18.0)
          .multilineTextAlignment(.center)
          .textSelection(.enabled)
      }
      if entry.repeat > 1 {
        CountButton(count: entry.repeat) { counterEntry = entry }
          .accessibilityIdentifier("slideshowCounter")
      }
    }
  }

  private var footer: some View {
    VStack(spacing: 18) {
      if entries.count > 1 && entries.count <= 12 {
        AZPageDots(count: entries.count, index: page)
          .accessibilityIdentifier("slideshowPagination")
      }
      HStack(spacing: AZSpace.sm) {
        if entries.count > 1 {
          Button { movePage(by: -1) } label: {
            Label(AZLocale.text("Previous", "السابق"), systemImage: "chevron.backward")
              .labelStyle(.titleAndIcon)
          }
          .buttonStyle(.az(.secondary, fullWidth: true))
          .disabled(page == 0)
          .accessibilityIdentifier("slideshowPrevious")
        }
        Button {
          if isLast {
            onComplete()
            dismiss()
          } else {
            movePage(by: 1)
          }
        } label: {
          HStack(spacing: 8) {
            Text(isLast ? AZLocale.text("Done", "تم") : AZLocale.text("Next", "التالي"))
            Image(systemName: isLast ? "checkmark" : "chevron.forward")
          }
        }
        .buttonStyle(.az(.primary, fullWidth: true))
        .accessibilityIdentifier(isLast ? "slideshowDone" : "slideshowNext")
      }
    }
    .padding(.horizontal, AZSpace.gutter)
    .padding(.bottom, AZSpace.lg)
  }

  private func movePage(by offset: Int) {
    let nextPage = page + offset
    guard entries.indices.contains(nextPage) else { return }
    withAnimation(AZMotion.animation(AZDuration.base, reduceMotion: reduceMotion)) {
      page = nextPage
    }
  }
}
