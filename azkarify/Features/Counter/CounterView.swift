import SwiftUI

struct CounterView: View {
  @EnvironmentObject private var store: AzkarStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var initialCount = 0
  var title = ""
  @AppStorage("accent") private var accent = "brown"
  @AppStorage("font") private var selectedFont = "ibmPlexSansArabic"
  @State private var count = 0

  var body: some View {
    VStack(spacing: 28) {
      if !title.isEmpty {
        Text(title).font(
          AppAppearance.font(
            language: store.language, choice: selectedFont, size: 18, relativeTo: .headline,
            bold: true)
        ).lineLimit(3)
      }
      Text(
        initialCount > 0
          ? AppCopy.text(
            "Tap the number to count down", "اضغط على الرقم للعد التنازلي", language: store.language
          )
          : AppCopy.text(
            "Tap the number to count up", "اضغط على الرقم للعد التصاعدي", language: store.language)
      )
      .font(
        AppAppearance.font(
          language: store.language, choice: selectedFont, size: 15, relativeTo: .subheadline))
      Button {
        changeCount(by: initialCount > 0 ? -1 : 1)
      } label: {
        ZStack {
          Circle()
            .stroke(AppAppearance.accent(accent).opacity(0.18), lineWidth: 2)
          if initialCount > 0 {
            Circle()
              .trim(from: 0, to: CGFloat(count) / CGFloat(initialCount))
              .stroke(
                AppAppearance.accent(accent), style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
              )
              .rotationEffect(.degrees(-90))
          }
          Text(count.formatted())
            .font(
              AppAppearance.font(
                language: store.language, choice: selectedFont, size: 60, relativeTo: .largeTitle,
                bold: true)
            )
            .contentTransition(.numericText())
            .foregroundStyle(.primary)
        }
        .frame(width: 190, height: 190)
        .shadow(color: AppAppearance.accent(accent).opacity(0.12), radius: 8, y: 3)
        .frame(maxWidth: .infinity)
      }
      .accessibilityLabel(
        AppCopy.text("Count: \(count)", "العدد: \(count)", language: store.language)
      )
      .accessibilityHint(
        AppCopy.text(
          "Double tap to change the count", "اضغط مرتين لتغيير العدد", language: store.language)
      )
      .accessibilityAdjustableAction { direction in
        switch direction {
        case .increment: changeCount(by: 1)
        case .decrement: changeCount(by: -1)
        @unknown default: break
        }
      }
      Button(AppCopy.text("Reset", "إعادة ضبط", language: store.language)) {
        changeCount(to: initialCount)
      }
      .frame(minHeight: 44)
    }
    .padding(24)
    .presentationDetents([.medium])
    .onAppear { count = initialCount }
  }

  private func changeCount(by value: Int) {
    let next = max(0, count + value)
    changeCount(to: initialCount > 0 ? min(initialCount, next) : next)
  }
  private func changeCount(to value: Int) {
    withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { count = value }
  }
}
