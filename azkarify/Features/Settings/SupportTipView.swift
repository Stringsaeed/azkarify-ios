import RevenueCat
import SwiftUI

struct SupportTipView: View {
  let offering: Offering
  let package: Package
  let language: String
  let accent: String

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.dismiss) private var dismiss
  @State private var isPurchasing = false
  @State private var didTip = false
  @State private var didTrackImpression = false
  @State private var purchaseError: String?

  private var accentColor: Color { AppAppearance.accent(accent) }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Spacer()
        Button { dismiss() } label: {
          Image(systemName: "xmark")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 44, height: 44)
            .background(accentColor.opacity(0.12), in: Circle())
        }
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
            SupportTipArtwork(accent: accentColor)
              .frame(height: min(190, max(136, geometry.size.height * 0.34)))
              .padding(.bottom, 18)

            Text(didTip ? copy("THANK YOU", "شكرًا لك")
                        : copy("A NOTE FROM THE MAKER", "رسالة من المطوّر"))
              .font(AppAppearance.font(size: 12, relativeTo: .caption, bold: true))
              .tracking(language == "ar" ? 0 : 1.8)
              .foregroundStyle(accentColor)
              .padding(.bottom, 12)

            Text(didTip
                 ? copy("Thank you for supporting Azkarify.", "شكرًا لدعم أذكاريفاي.")
                 : copy("A little support goes a long way.",
                        "دعم صغير يصنع فرقًا كبيرًا"))
              .font(AppAppearance.font(size: 32, relativeTo: .largeTitle, bold: true))
              .foregroundStyle(.primary)
              .multilineTextAlignment(.center)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.bottom, 14)

            Text(didTip
                 ? copy("Your tip helps me maintain and improve the app.",
                        "تساعدني مساهمتك على صيانة التطبيق وتطويره.")
                 : copy("Azkarify is free for everyone. A one-time tip helps me maintain and improve it.",
                        "أذكاريفاي مجاني للجميع. مساهمتك لمرة واحدة تساعدني على صيانته وتطويره."))
              .font(AppAppearance.font(size: 17))
              .foregroundStyle(.secondary)
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
    .background { BotanicalBackground(accent: accent) }
    .environment(\.layoutDirection, language == "ar" ? .rightToLeft : .leftToRight)
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
        .fill(accentColor.opacity(0.25))
        .frame(height: 1)

      if !didTip {
        Text(copy("ONE-TIME TIP", "مساهمة لمرة واحدة"))
          .font(AppAppearance.font(size: 12, relativeTo: .caption, bold: true))
          .tracking(language == "ar" ? 0 : 1.2)
          .foregroundStyle(accentColor)
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
            ProgressView().tint(colorScheme == .dark ? .black : .white)
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
        .font(AppAppearance.font(size: 18, relativeTo: .headline, bold: true))
        .frame(maxWidth: .infinity, minHeight: 56)
        .foregroundStyle(colorScheme == .dark ? Color.black.opacity(0.85) : .white)
        .background(accentColor, in: RoundedRectangle(cornerRadius: 16))
      }
      .buttonStyle(.plain)
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
          .font(AppAppearance.font(size: 13, relativeTo: .footnote))
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
    }
    .padding(.horizontal, 24)
    .padding(.top, 14)
    .padding(.bottom, 12)
    .background(AppAppearance.background(accent))
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
  let accent: Color

  var body: some View {
    ZStack {
      Circle()
        .fill(accent.opacity(0.07))
        .frame(width: 190, height: 190)
      TipArch()
        .stroke(accent.opacity(0.85), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        .frame(width: 138, height: 164)
      TipArch()
        .stroke(accent.opacity(0.3), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        .frame(width: 126, height: 152)
      Image(systemName: "moon.fill")
        .font(.system(size: 26))
        .foregroundStyle(accent)
        .offset(y: -48)
      Image(systemName: "leaf")
        .font(.system(size: 34, weight: .ultraLight))
        .foregroundStyle(accent.opacity(0.8))
        .rotationEffect(.degrees(-28))
        .offset(x: 28, y: 64)
    }
    .frame(maxWidth: .infinity)
    .accessibilityHidden(true)
  }
}

private struct TipArch: Shape {
  func path(in rect: CGRect) -> Path {
    let width = rect.width
    let height = rect.height
    var path = Path()
    path.move(to: CGPoint(x: width * 0.18, y: height * 0.96))
    path.addLine(to: CGPoint(x: width * 0.18, y: height * 0.39))
    path.addQuadCurve(
      to: CGPoint(x: width * 0.27, y: height * 0.31),
      control: CGPoint(x: width * 0.18, y: height * 0.32))
    path.addQuadCurve(
      to: CGPoint(x: width * 0.5, y: height * 0.04),
      control: CGPoint(x: width * 0.31, y: height * 0.11))
    path.addQuadCurve(
      to: CGPoint(x: width * 0.73, y: height * 0.31),
      control: CGPoint(x: width * 0.69, y: height * 0.11))
    path.addQuadCurve(
      to: CGPoint(x: width * 0.82, y: height * 0.39),
      control: CGPoint(x: width * 0.82, y: height * 0.32))
    path.addLine(to: CGPoint(x: width * 0.82, y: height * 0.96))
    return path
  }
}
