import SwiftUI

struct CounterView: View {
  @EnvironmentObject private var store: AzkarStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var initialCount = 0
  var title = ""
  @AppStorage("accent") private var accent = "brown"
  @State private var count = 0
  @State private var audio = CounterAudio()
  @State private var contentHeight: CGFloat = 420
  @State private var selectedDetent: PresentationDetent = .height(420)

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        if !title.isEmpty {
          Text(title)
            .textSelection(.enabled)
            .font(
              AppAppearance.font(
                size: 20, relativeTo: .title3)
            )
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        counterControls
      }
      .fixedSize(horizontal: false, vertical: true)
      .padding(24)
      .frame(maxWidth: .infinity)
    }
    .accessibilityIdentifier("counterZikrScroll")
    .background(AppAppearance.background(accent))
    .onScrollGeometryChange(for: CGFloat.self) { $0.contentSize.height } action: { _, height in
      contentHeight = height
      selectedDetent = height > maximumSheetHeight ? .large : .height(height)
    }
    .presentationDetents(
      [.height(min(contentHeight, maximumSheetHeight)), .large], selection: $selectedDetent)
    .environment(\.layoutDirection, store.language == "ar" ? .rightToLeft : .leftToRight)
    .onAppear {
      count = initialCount
      audio.prepare()
    }
    .onDisappear { audio.stop() }
  }

  private var maximumSheetHeight: CGFloat {
    let scene = UIApplication.shared.connectedScenes
      .first { $0.activationState == .foregroundActive } as? UIWindowScene
    return (scene?.screen.bounds.height ?? 800) * 0.9
  }

  private var counterControls: some View {
    VStack(spacing: 20) {
      Text(
        initialCount > 0
          ? AppCopy.text("Tap the number to count down")
          : AppCopy.text("Tap the number to count up")
      )
      .font(
        AppAppearance.font(
          size: 15, relativeTo: .subheadline))
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
                size: 60, relativeTo: .largeTitle,
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
        AppCopy.format("Count: %lld", count)
      )
      .accessibilityHint(
        AppCopy.text("Double tap to change the count")
      )
      .accessibilityAdjustableAction { direction in
        switch direction {
        case .increment: changeCount(by: 1)
        case .decrement: changeCount(by: -1)
        @unknown default: break
        }
      }
      Button(AppCopy.text("Reset")) {
        changeCount(to: initialCount, cue: .reset)
      }
      .frame(minHeight: 44)
    }
  }

  private func changeCount(by value: Int) {
    let next = max(0, count + value)
    let value = initialCount > 0 ? min(initialCount, next) : next
    changeCount(to: value, cue: initialCount > 0 && value == 0 ? .completion : .tick)
  }
  private func changeCount(to value: Int, cue: CounterAudio.Cue) {
    guard value != count else { return }
    withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { count = value }
    audio.play(cue)
  }
}
