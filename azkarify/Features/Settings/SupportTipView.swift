import RevenueCat
import SwiftUI

struct SupportTipView: View {
  let offering: Offering
  let package: Package
  let language: String
  let accent: String

  @Environment(\.dismiss) private var dismiss
  @State private var isPurchasing = false
  @State private var didTip = false
  @State private var didTrackImpression = false
  @State private var purchaseError: String?


  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Spacer()
        Button { dismiss() } label: {
          Image(systemName: "xmark")
        }
        .buttonStyle(.azIcon(.filled))
        .accessibilityLabel(copy("Close", "إغلاق"))
        .accessibilityIdentifier("support-tip.close")
        .disabled(isPurchasing)
      }
      .padding(.horizontal, 20)
      .padding(.top, 8)

      GeometryReader { geometry in
        ScrollView {
          VStack(spacing: 0) {
            Spacer(minLength: 16)
            SupportTipArtwork()
              .frame(height: min(200, max(150, geometry.size.height * 0.34)))
              .padding(.bottom, 18)

            Text(didTip ? copy("THANK YOU", "شكرًا لك")
                        : copy("A NOTE FROM THE MAKER", "رسالة من المطوّر"))
              .azText(.eyebrow)
              .foregroundStyle(AZColor.sparkInk)
              .padding(.bottom, 12)

            Text(didTip
                 ? copy("Thank you for supporting Azkarify.", "شكرًا لدعم أذكاريفاي.")
                 : copy("A little support goes a long way.",
                        "دعم صغير يصنع فرقًا كبيرًا"))
              .azText(.title1)
              .foregroundStyle(AZColor.ink)
              .multilineTextAlignment(.center)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.bottom, 14)

            Text(didTip
                 ? copy("Your tip helps me maintain and improve the app.",
                        "تساعدني مساهمتك على صيانة التطبيق وتطويره.")
                 : copy("Azkarify is free for everyone. A one-time tip helps me maintain and improve it.",
                        "أذكاريفاي مجاني للجميع. مساهمتك لمرة واحدة تساعدني على صيانته وتطويره."))
              .azText(.body)
              .foregroundStyle(AZColor.inkMuted)
              .multilineTextAlignment(.center)
              .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 16)
          }
          .padding(.horizontal, 28)
          .frame(maxWidth: .infinity)
          .frame(minHeight: geometry.size.height)
        }
        .scrollIndicators(.hidden)
      }

      footer
    }
    .azScreenBackground()
    .onAppear {
      guard !didTrackImpression else { return }
      didTrackImpression = true
      Purchases.shared.trackCustomPaywallImpression(
        CustomPaywallImpressionParams(
          paywallId: "azkarify-support-tip-native", offering: offering))
    }
    .alert(
      copy("Unable to complete tip", "تعذّر إتمام المساهمة"),
      isPresented: Binding(
        get: { purchaseError != nil },
        set: { if !$0 { purchaseError = nil } }
      )
    ) {
      Button(copy("OK", "حسنًا")) { purchaseError = nil }
    } message: {
      Text(purchaseError ?? "")
    }
  }

  private var footer: some View {
    VStack(spacing: 12) {
      Rectangle()
        .fill(AZColor.line)
        .frame(height: AZBorder.hairline)

      if !didTip {
        Text(copy("ONE-TIME TIP", "مساهمة لمرة واحدة"))
          .azText(.eyebrow)
          .foregroundStyle(AZColor.inkMuted)
      }

      Button {
        if didTip {
          dismiss()
        } else {
          Task { await purchaseTip() }
        }
      } label: {
        Group {
          if isPurchasing {
            ProgressView().tint(AZColor.paper)
          } else if didTip {
            Text(copy("Done", "تم"))
          } else {
            ViewThatFits(in: .horizontal) {
              HStack(spacing: 6) {
                Text(copy("Leave a tip", "قدّم مساهمة"))
                Text("·")
                Text(package.localizedPriceString)
              }
              VStack(spacing: 2) {
                Text(copy("Leave a tip", "قدّم مساهمة"))
                Text(package.localizedPriceString)
              }
            }
          }
        }
      }
      .buttonStyle(.az(.primary, fullWidth: true))
      .disabled(isPurchasing)
      .accessibilityLabel(
        didTip ? copy("Done", "تم")
        : copy("Leave a tip for \(package.localizedPriceString)",
               "قدّم مساهمة بقيمة \(package.localizedPriceString)")
      )
      .accessibilityIdentifier(didTip ? "support-tip.done" : "support-tip.purchase")

      if !didTip {
        Text(copy("Entirely optional. All azkar remain free.",
                  "الدعم اختياري تمامًا. جميع الأذكار متاحة مجانًا."))
          .azText(.footnote)
          .foregroundStyle(AZColor.inkMuted)
          .multilineTextAlignment(.center)
      }
    }
    .padding(.horizontal, 24)
    .padding(.top, 14)
    .padding(.bottom, 12)
    .background(AZColor.paper)
  }

  @MainActor
  private func purchaseTip() async {
    isPurchasing = true
    defer { isPurchasing = false }
    do {
      let result = try await Purchases.shared.purchase(package: package)
      if !result.userCancelled { didTip = true }
    } catch {
      purchaseError = error.localizedDescription
    }
  }

  private func copy(_ english: String, _ arabic: String) -> String {
    language == "ar" ? arabic : english
  }
}

private struct SupportTipArtwork: View {
  var body: some View {
    ZStack {
      Circle().fill(AZColor.mist).frame(width: 190, height: 190)
      AZJourneyArch(width: 128, height: 172) {
        AZOrnament(shape: .crescent, size: 52, color: AZColor.forest)
      }
      AZOrnament(shape: .sparkle, size: 26, color: AZColor.spark)
        .offset(x: 78, y: -66)
    }
    .frame(maxWidth: .infinity)
    .accessibilityHidden(true)
  }
}
