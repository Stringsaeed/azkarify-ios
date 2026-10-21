import SwiftUI

/// The points badge for a toolbar. Tapping it opens the points sheet.
struct PointsToolbarButton: View {
  @EnvironmentObject private var progress: JourneyProgressStore
  @State private var showDetails = false

  var body: some View {
    Button { showDetails = true } label: {
      AZPointsBadge(points: progress.totalPoints)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(AZLocale.text("Your points", "نقاطك"))
    .accessibilityValue(String(progress.totalPoints))
    .accessibilityIdentifier("journey-total-points")
    .sheet(isPresented: $showDetails) {
      JourneyPointsDetails()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
  }
}

private struct JourneyPointsDetails: View {
  @EnvironmentObject private var progress: JourneyProgressStore
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      ScrollView {
        VStack(alignment: .leading, spacing: AZSpace.md) {
          HStack {
            Text(text("Your points", "نقاطك")).azText(.title2)
            Spacer()
            Button(text("Done", "تم")) { dismiss() }
              .buttonStyle(.azText)
              .accessibilityIdentifier("points.dismiss")
          }
          HStack(spacing: AZSpace.sm) {
            AZOrnament(shape: .star, size: 40, color: AZColor.spark)
            Text(AZLocale.number(progress.totalPoints))
              .azText(.numeral, scale: 0.6)
              .monospacedDigit()
              .accessibilityLabel(text("Total points", "مجموع النقاط"))
              .accessibilityValue(String(progress.totalPoints))
          }
          Text(text("Total points for today: \(progress.pointsEarned(on: context.date))",
                    "مجموع نقاط اليوم: \(AZLocale.number(progress.pointsEarned(on: context.date)))"))
            .azText(.headline)
            .accessibilityIdentifier("points.today")
          VStack(alignment: .leading, spacing: AZSpace.sm) {
            Text(text(
              "\(JourneyProgressStore.stepPoints) points per step, plus \(JourneyProgressStore.journeyCompletionPoints) per journey and \(JourneyProgressStore.slideshowCompletionPoints) per completed focus session. Each step, journey, and category earns its reward once a day. Earned points stay yours if you undo a step.",
              "\(AZLocale.number(JourneyProgressStore.stepPoints)) نقاط لكل خطوة، و\(AZLocale.number(JourneyProgressStore.journeyCompletionPoints)) نقطة إضافية لكل رحلة، و\(AZLocale.number(JourneyProgressStore.slideshowCompletionPoints)) نقطة عند إكمال وضع التركيز. تُكتسب مكافأة كل خطوة ورحلة وباب مرة واحدة يومياً، وتبقى نقاطك إذا ألغيت إكمال خطوة."))
            Text(text("Earn 1 point for every 33 counts in the counter. Progress toward the next point is saved between sessions.",
                      "اكسب نقطة واحدة لكل ٣٣ تسبيحة في السبحة. يُحفظ تقدمك نحو النقطة التالية بين الجلسات."))
          }
          .azText(.body)
          HStack(spacing: AZSpace.sm) {
            Image(systemName: "lock")
              .accessibilityHidden(true)
            Text(text("Saved on this device only. Future syncing will require your agreement.",
                      "محفوظة على هذا الجهاز فقط. لن تتم المزامنة مستقبلاً إلا بموافقتك."))
              .azText(.footnote)
          }
          .azCard(.forest, compact: true)
        }
        .foregroundStyle(AZColor.ink)
        .padding(AZSpace.xl)
      }
      .azScreenBackground()
    }
  }

  private func text(_ english: String, _ arabic: String) -> String {
    AZLocale.text(english, arabic)
  }
}
