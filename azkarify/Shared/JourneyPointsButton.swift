import SwiftUI

struct JourneyPointsButton: View {
  @EnvironmentObject private var store: AzkarStore
  @EnvironmentObject private var progress: JourneyProgressStore
  @State private var showDetails = false

  var body: some View {
    Button { showDetails = true } label: {
      HStack(spacing: 4) {
        PointsCurrencyIcon().frame(width: 25, height: 25)
        Text(progress.totalPoints.formatted(.number.locale(Locale(identifier: store.language))))
          .font(AppAppearance.font(size: 15, bold: true))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .frame(minHeight: 44)
    }
    .accessibilityLabel(store.language == "ar" ? "نقاطك" : "Your points")
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
  @EnvironmentObject private var store: AzkarStore
  @EnvironmentObject private var progress: JourneyProgressStore
  @Environment(\.dismiss) private var dismiss
  @AppStorage("accent") private var accent = "brown"

  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          HStack {
            Text(text("Your points", "نقاطك"))
              .font(AppAppearance.font(size: 24, relativeTo: .title2, bold: true))
            Spacer()
            Button(text("Done", "تم")) { dismiss() }
              .font(AppAppearance.font(size: 15, bold: true))
              .accessibilityIdentifier("points.dismiss")
          }
          HStack(spacing: 10) {
            PointsCurrencyIcon().frame(width: 48, height: 48)
            Text(progress.totalPoints.formatted(.number.locale(Locale(identifier: store.language))))
              .font(AppAppearance.font(size: 36, relativeTo: .largeTitle, bold: true))
              .accessibilityLabel(text("Total points", "مجموع النقاط"))
              .accessibilityValue(String(progress.totalPoints))
          }
          Text(text("Total points for today: \(progress.pointsEarned(on: context.date))",
                    "مجموع نقاط اليوم: \(progress.pointsEarned(on: context.date))"))
            .font(AppAppearance.font(size: 17, bold: true))
            .accessibilityIdentifier("points.today")
          Text(text(
            "\(JourneyProgressStore.stepPoints) points per step, plus \(JourneyProgressStore.journeyCompletionPoints) per journey. Each reward is earned once a day. Earned points stay yours if you undo a step.",
            "\(JourneyProgressStore.stepPoints) نقاط لكل خطوة، و\(JourneyProgressStore.journeyCompletionPoints) نقطة إضافية لكل رحلة. تُكتسب كل مكافأة مرة واحدة يومياً، وتبقى نقاطك إذا ألغيت إكمال خطوة."))
            .font(AppAppearance.font(size: 15))
          Text(text("Saved on this device only. Future syncing will require your agreement.",
                    "محفوظة على هذا الجهاز فقط. لن تتم المزامنة مستقبلاً إلا بموافقتك."))
            .font(AppAppearance.font(size: 14))
            .foregroundStyle(.secondary)
          Text(text("Earn 1 point for every 33 counts in the counter. Progress toward the next point is saved between sessions.",
                    "اكسب نقطة واحدة لكل ٣٣ تسبيحة في السبحة. يُحفظ تقدمك نحو النقطة التالية بين الجلسات."))
            .font(AppAppearance.font(size: 15))
        }
        .padding(24)
      }
      .background(AppAppearance.background(accent))
    }
    .environment(\.layoutDirection, store.language == "ar" ? .rightToLeft : .leftToRight)
  }

  private func text(_ english: String, _ arabic: String) -> String {
    store.language == "ar" ? arabic : english
  }
}
