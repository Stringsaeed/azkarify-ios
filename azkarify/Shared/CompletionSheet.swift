import SwiftUI

/// What a finished journey or focus session earned, shown once in one sheet.
struct CompletionSummary: Identifiable, Equatable {
  let id = UUID()
  let stickerLabel: String
  let title: String
  let message: String
  let pointsEarned: Int
  let totalPoints: Int
}

/// The celebration: check (0–150 ms), points tick up (150–500 ms), then still.
struct CompletionSheet: View {
  let summary: CompletionSummary
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var settled = false

  var body: some View {
    VStack(spacing: 0) {
      ZStack {
        AZOrnament(shape: .star, size: 34, color: AZColor.spark)
          .offset(x: -110, y: -50)
        AZOrnament(shape: .sparkle, size: 26, color: AZColor.forest)
          .offset(x: 100, y: 48)
        AZSticker(label: summary.stickerLabel, large: true) {
          AZOrnament(shape: .sparkle, size: 22, color: AZColor.forest)
        }
        .scaleEffect(settled || reduceMotion ? 1 : 0.92)
        .opacity(settled || reduceMotion ? 1 : 0)
      }
      .frame(height: 150)
      .padding(.top, AZSpace.lg)

      Text(summary.title)
        .azText(.title2)
        .multilineTextAlignment(.center)
        .padding(.top, AZSpace.xs)
      Text(summary.message)
        .azText(.body)
        .foregroundStyle(AZColor.inkMuted)
        .multilineTextAlignment(.center)
        .padding(.top, 6)

      if summary.pointsEarned > 0 {
        HStack(spacing: 10) {
          HStack(spacing: 6) {
            AZOrnament(shape: .star, size: 18, color: AZColor.spark)
            Text("+" + AZLocale.number(settled ? summary.pointsEarned : 0))
              .azText(.headline)
              .monospacedDigit()
              .contentTransition(.numericText(value: Double(settled ? summary.pointsEarned : 0)))
          }
          .padding(.leading, 8)
          .padding(.trailing, 12)
          .frame(height: 40)
          .background(AZColor.paperRaised, in: Capsule())
          .overlay { Capsule().strokeBorder(.azStampOutline, lineWidth: AZBorder.hairline) }
          Text(AZLocale.text("\(summary.totalPoints) points in total",
                             "\(AZLocale.number(summary.totalPoints)) نقطة في المجموع"))
            .azText(.callout)
            .foregroundStyle(AZColor.inkMuted)
        }
        .padding(.top, AZSpace.lg)
        .accessibilityElement(children: .combine)
      }

      Spacer(minLength: AZSpace.xl)
      Button(AZLocale.text("Done", "تم")) { dismiss() }
        .buttonStyle(.az(.primary, fullWidth: true))
        .accessibilityIdentifier("completion.done")
    }
    .foregroundStyle(AZColor.ink)
    .padding(.horizontal, AZSpace.xl)
    .padding(.bottom, AZSpace.lg)
    .frame(maxWidth: .infinity)
    .background(AZColor.paper.ignoresSafeArea())
    .presentationDetents([.height(470)])
    .presentationDragIndicator(.visible)
    .sensoryFeedback(.success, trigger: settled) { _, new in new }
    .task {
      try? await Task.sleep(for: .milliseconds(150))
      withAnimation(AZMotion.animation(0.35, reduceMotion: reduceMotion)) { settled = true }
    }
    // Contain, so the sheet's identifier doesn't replace the Done button's.
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("completionSheet")
  }
}
