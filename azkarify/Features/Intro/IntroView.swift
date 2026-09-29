import SwiftUI

struct IntroView: View {
  @EnvironmentObject private var store: AzkarStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("accent") private var accent = "brown"
  let onFinish: () -> Void
  @State private var page = 0

  private let pages: [(String, String, String)] = [
    (
      "📖", "Browse azkar",
      "Find a zikr by topic or search for it."
    ),
    (
      "text.📖", "Read and reflect",
      "Open a topic to read its azkar or use the slideshow."
    ),
    (
      "⭐", "Save favorites",
      "Keep the topics you return to close at hand."
    ),
    (
      "⚡", "Quick Mode",
      "Start with morning, evening, sleep, or waking azkar."
    ),
    (
      "📿", "Use the counter",
      "Tap to count, or count down repeated azkar."
    ),
    (
      "🔔", "Set reminders",
      "Choose morning and evening times in Settings."
    ),
    (
      "🎨", "Make it yours",
      "Choose an accent color. Change language in iOS Settings."
    ),
    (
      "💛", "Support the app",
      "Find ways to support future updates in Settings."
    ),
  ]

  var body: some View {
    VStack(spacing: 20) {
      HStack {
        Spacer()
        Button(AppCopy.text("Skip"), action: onFinish)
          .frame(minHeight: 44)
      }
      .padding(.horizontal, 24)

      TabView(selection: $page) {
        ForEach(pages.indices, id: \.self) { index in
          let item = pages[index]
          VStack(spacing: 28) {
            Text(item.0)
              .font(.system(size: 60))
              .frame(width: 160, height: 160)
              .background(.regularMaterial, in: Circle())
              .overlay(Circle().stroke(AppAppearance.accent(accent).opacity(0.35), lineWidth: 1.5))
              .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
              .accessibilityHidden(true)
            Text(AppCopy.text(item.1))
              .font(
                AppAppearance.font(
                  size: 34, relativeTo: .largeTitle,
                  bold: true)
              )
              .multilineTextAlignment(.center)
            Text(AppCopy.text(item.2))
              .font(
                AppAppearance.font(
                  size: 20, relativeTo: .title3)
              )
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }
          .padding(24)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .tag(index)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))

      HStack(spacing: 8) {
        ForEach(pages.indices, id: \.self) { index in
          Circle()
            .fill(index == page ? AppAppearance.accent(accent) : Color.secondary.opacity(0.3))
            .frame(width: index == page ? 8 : 6, height: index == page ? 8 : 6)
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        AppCopy.format("Page %lld of %lld", page + 1, pages.count))

      Button {
        if page == pages.count - 1 {
          onFinish()
        } else {
          withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { page += 1 }
        }
      } label: {
        Text(
          page == pages.count - 1
            ? AppCopy.text("Get started")
            : AppCopy.text("Next")
        )
        .frame(maxWidth: .infinity, minHeight: 52)
      }
      .buttonStyle(.borderedProminent)
      .padding(.horizontal, 24)
      .padding(.bottom, 24)
    }
    .background(AppAppearance.background)
    .environment(\.layoutDirection, store.language == "ar" ? .rightToLeft : .leftToRight)
  }
}
