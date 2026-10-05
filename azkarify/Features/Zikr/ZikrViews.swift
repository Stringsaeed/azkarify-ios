import SwiftUI
import UIKit

struct ZikrListView: View {
  @AppStorage("accent") private var accent = "brown"
  @EnvironmentObject private var store: AzkarStore
  @EnvironmentObject private var progress: JourneyProgressStore
  let category: ZikrCategory
  @State private var entries: [ZikrEntry] = []
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var showSlideshow = false
  @State private var completionOrigin: CGPoint?
  @Environment(\.celebrate) private var celebrate

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
        UIApplication.shared.sendAction(
          #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        completionOrigin = nil
        showSlideshow = true
      } label: {
        Image(systemName: "slider.horizontal.below.rectangle")
      }
      .disabled(entries.isEmpty)
      .accessibilityLabel(AppCopy.text("Slideshow"))
    }
    .fullScreenCover(isPresented: $showSlideshow, onDismiss: {
      if let completionOrigin {
        progress.completeSlideshow(categoryID: category.id)
        celebrate(completionOrigin)
      }
    }) {
      SlideshowView(entries: entries, title: category.title) { origin in
        completionOrigin = origin
      }
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
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @EnvironmentObject private var store: AzkarStore
  let entries: [ZikrEntry]
  let title: String
  let onComplete: (CGPoint) -> Void
  @State private var page = 0
  @State private var doneButtonOrigin = CGPoint.zero
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
                  size: 17, relativeTo: .body)
              )
              .multilineTextAlignment(.leading)
              .frame(maxWidth: .infinity, alignment: .leading)
              .fixedSize(horizontal: false, vertical: true)
              .padding(24)
              .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
              .padding(16)
          }
          .tag(index)
          .accessibilityLabel(
            AppCopy.format("Zikr %lld of %lld", index + 1, entries.count))
        }
      }
      .tabViewStyle(
        .page(indexDisplayMode: .never)
      )
      .background(AppAppearance.background(accent))
      .appNavigationTitle(title, language: store.language)
      .toolbar {
        if showsCounter {
          ToolbarItem(placement: .topBarLeading) {
            counterButton
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
          }
          .accessibilityLabel(AppCopy.text("Close"))
        }
      }
      .safeAreaInset(edge: .bottom) {
        if !entries.isEmpty {
          slideshowChrome
        }
      }
      .sheet(isPresented: $showCounter) {
        CounterView(initialCount: currentEntry?.repeat ?? 0, title: currentText)
          .id(currentEntry?.id)
      }
    }
    .environment(\.layoutDirection, store.language == "ar" ? .rightToLeft : .leftToRight)
  }

  private var showsProgress: Bool {
    Celebration.showsSlideshowProgress(entryCount: entries.count)
  }

  private var showsCounter: Bool {
    (currentEntry?.repeat ?? 0) > 1
  }

  private var counterButton: some View {
    Button {
      showCounter = true
    } label: {
      Label {
        Text("\(currentEntry?.repeat ?? 0)")
      } icon: {
        Text("📿")
      }
      .labelStyle(.titleAndIcon)
      .font(AppAppearance.font(size: 17, relativeTo: .body))
      .frame(minWidth: 44, minHeight: 44)
    }
    .accessibilityLabel(AppCopy.format("Count down from %lld", currentEntry?.repeat ?? 0))
    .accessibilityIdentifier("slideshowCounter")
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: showsCounter)
  }

  private var slideshowChrome: some View {
    VStack(spacing: 12) {
      if showsProgress {
        ProgressView(value: Double(page + 1), total: Double(entries.count))
          .tint(AppAppearance.accent(accent))
          .accessibilityHidden(true)
          .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: page)
        Text(AppCopy.format("%lld of %lld", page + 1, entries.count))
          .font(AppAppearance.font(size: 17, relativeTo: .headline, bold: true))
          .foregroundStyle(AppAppearance.accent(accent))
          .monospacedDigit()
          .accessibilityIdentifier("slideshowProgress")
      }
      if entries.count == 2 {
        HStack(spacing: 8) {
          ForEach(entries.indices, id: \.self) { index in
            Circle()
              .fill(AppAppearance.accent(accent).opacity(page == index ? 1 : 0.25))
              .frame(width: 7, height: 7)
          }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppCopy.format("%lld of %lld", page + 1, entries.count))
        .accessibilityIdentifier("slideshowPagination")
      }
      if !entries.isEmpty {
        HStack(spacing: 16) {
          if entries.count > 1 {
            Button {
              movePage(by: -1)
            } label: {
              ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                  Image(systemName: previousIcon)
                  Text(AppCopy.text("Previous"))
                }
                .fixedSize(horizontal: true, vertical: false)
                Image(systemName: previousIcon)
              }
              .frame(minWidth: 44, minHeight: 44)
              .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(page == 0)
            .accessibilityLabel(AppCopy.text("Previous"))
            .accessibilityIdentifier("slideshowPrevious")
          }
          Button {
            if page == entries.count - 1 {
              onComplete(doneButtonOrigin)
              dismiss()
            } else {
              movePage(by: 1)
            }
          } label: {
            ViewThatFits(in: .horizontal) {
              HStack(spacing: 6) {
                Text(AppCopy.text(page == entries.count - 1 ? "Done" : "Next"))
                Image(systemName: nextIcon)
              }
              .fixedSize(horizontal: true, vertical: false)
              Image(systemName: nextIcon)
            }
            .frame(minWidth: 44, minHeight: 44)
            .onGeometryChange(for: CGPoint.self) { geometry in
              let frame = geometry.frame(in: .global)
              return CGPoint(x: frame.midX, y: frame.midY)
            } action: { origin in
              doneButtonOrigin = origin
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
          }
          .accessibilityLabel(AppCopy.text(page == entries.count - 1 ? "Done" : "Next"))
          .accessibilityIdentifier(entries.count == 1 ? "slideshowDone" : "slideshowNext")
        }
        .font(AppAppearance.font(size: 17, relativeTo: .headline, bold: true))
      }
    }
    .tint(AppAppearance.accent(accent))
    .environment(\.layoutDirection, store.language == "ar" ? .rightToLeft : .leftToRight)
    .padding(.horizontal, 24)
    .padding(.top, 12)
    .padding(.bottom, 8)
    .background(AppAppearance.background(accent))
  }

  private var previousIcon: String {
    store.language == "ar" ? "chevron.right" : "chevron.left"
  }

  private var nextIcon: String {
    page == entries.count - 1 ? "checkmark" :
      (store.language == "ar" ? "chevron.left" : "chevron.right")
  }

  private func movePage(by offset: Int) {
    let nextPage = page + offset
    guard entries.indices.contains(nextPage) else { return }
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
      page = nextPage
    }
  }
}
