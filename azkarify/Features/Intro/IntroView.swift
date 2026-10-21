import SwiftUI

struct IntroView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let onFinish: () -> Void
  @State private var page = 0

  private struct Page {
    let ornament: AZOrnamentShape
    let eyebrow: String
    let title: String
    var highlight: String?
    let body: String
  }

  private let pages: [Page] = [
    Page(
      ornament: .star,
      eyebrow: AZLocale.text("A little remembrance. Every day.", "قليل من الذكر. كل يوم."),
      title: AZLocale.text("Small moments.\nDeeper connection.", "لحظات صغيرة.\nصلة أعمق."),
      highlight: AZLocale.text("Deeper", "أعمق"),
      body: AZLocale.text(
        "Morning light. A quiet commute. The last few minutes before sleep. Make a little room for dhikr, wherever life finds you.",
        "نور الصباح. طريق هادئ. دقائق قليلة قبل النوم. اجعل للذكر مكاناً صغيراً، أينما كنت.")),
    Page(
      ornament: .sun,
      eyebrow: AZLocale.text("Today", "اليوم"),
      title: AZLocale.text("A rhythm\nof your own.", "إيقاع\nيناسبك."),
      body: AZLocale.text(
        "Journeys for the morning, each prayer and the evening. Follow the steps at your own pace.",
        "رحلات للصباح ولكل صلاة وللمساء. أكمل خطواتها على مهل.")),
    Page(
      ornament: .sparkle,
      eyebrow: AZLocale.text("Azkar and counter", "الأذكار والسبحة"),
      title: AZLocale.text("Read, then\ncount.", "اقرأ،\nثم سبّح."),
      body: AZLocale.text(
        "Every zikr from Hisn al-Muslim, offline. Tap a zikr's count to open the counter.",
        "أذكار حصن المسلم كاملة، دون اتصال. انقر على عدد التكرار لفتح السبحة.")),
    Page(
      ornament: .crescent,
      eyebrow: AZLocale.text("Settings", "الإعدادات"),
      title: AZLocale.text("Make it\nyours.", "اجعله\nلك."),
      body: AZLocale.text(
        "Choose an accent, set reminders and your prayer location. Your progress stays on this device.",
        "اختر لون التمييز واضبط التذكيرات وموقع الصلاة. يبقى تقدمك على هذا الجهاز.")),
  ]

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Spacer()
        Button(AZLocale.text("Skip", "تخطي"), action: onFinish)
          .buttonStyle(.azText)
          .foregroundStyle(AZColor.inkMuted)
      }
      .padding(.horizontal, AZSpace.sm)

      TabView(selection: $page) {
        ForEach(pages.indices, id: \.self) { index in
          ScrollView {
            VStack(alignment: .leading, spacing: 14) {
              hero(for: index).frame(maxWidth: .infinity)
              Text(pages[index].eyebrow).azText(.eyebrow).foregroundStyle(AZColor.sparkInk)
                .padding(.top, 18)
              title(pages[index])
                .azText(.display)
                .accessibilityAddTraits(.isHeader)
              Text(pages[index].body).azText(.body).foregroundStyle(AZColor.inkMuted)
            }
            .foregroundStyle(AZColor.ink)
            .padding(.horizontal, AZSpace.xl)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
          }
          .scrollBounceBehavior(.basedOnSize)
          .tag(index)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))

      VStack(spacing: AZSpace.lg) {
        AZPageDots(count: pages.count, index: page)
        Button(page == pages.count - 1 ? AZLocale.text("Get started", "ابدأ") : AZLocale.text("Next", "التالي")) {
          if page == pages.count - 1 {
            onFinish()
          } else {
            withAnimation(AZMotion.animation(AZDuration.base, reduceMotion: reduceMotion)) { page += 1 }
          }
        }
        .buttonStyle(.az(.primary, fullWidth: true))
      }
      .padding(.horizontal, AZSpace.xl)
      .padding(.bottom, AZSpace.xl)
    }
    .azScreenBackground()
  }

  private func title(_ page: Page) -> Text {
    guard let highlight = page.highlight, let range = page.title.range(of: highlight) else {
      return Text(page.title)
    }
    var attributed = AttributedString(page.title)
    if let attributedRange = Range(range, in: attributed) {
      attributed[attributedRange].foregroundColor = AZColor.sparkInk
    }
    return Text(attributed)
  }

  @ViewBuilder
  private func hero(for index: Int) -> some View {
    let page = pages[index]
    ZStack {
      Circle().fill(AZColor.mist).frame(width: 300, height: 300)
      Ellipse().stroke(AZColor.orbit, lineWidth: AZBorder.hairline)
        .frame(width: 340, height: 188).rotationEffect(.degrees(-35))
      Ellipse().stroke(AZColor.orbit, lineWidth: AZBorder.hairline)
        .frame(width: 290, height: 240).rotationEffect(.degrees(50))
      AZJourneyArch(width: 168, height: 232) {
        if index == 0 {
          Text("ذكر")
            .font(.custom("AlanSans-Bold", size: 56, relativeTo: .largeTitle))
            .foregroundStyle(AZColor.forest)
            .rotationEffect(.degrees(-12))
        } else {
          AZOrnament(shape: page.ornament, size: 72,
                     color: page.ornament == .sparkle ? AZColor.forest : AZColor.spark)
        }
      }
      .overlay {
        UnevenRoundedRectangle(topLeadingRadius: 84, bottomLeadingRadius: AZRadius.lg,
                               bottomTrailingRadius: AZRadius.lg, topTrailingRadius: 84)
          .strokeBorder(.azStampOutline, lineWidth: AZBorder.stamp)
      }
      .azStamp(AZStamp.lg, shape: UnevenRoundedRectangle(
        topLeadingRadius: 84, bottomLeadingRadius: AZRadius.lg,
        bottomTrailingRadius: AZRadius.lg, topTrailingRadius: 84))
      .rotationEffect(.degrees(6))
      if index == 0 {
        AZOrnament(shape: .star, size: 96, color: AZColor.spark, spins: true)
          .offset(x: 120, y: -110)
        AZSticker(label: AZLocale.text("Less scrolling.\nMore soul.", "تصفح أقل.\nروح أكثر."))
          .rotationEffect(.degrees(-6))
          .offset(x: -100, y: 110)
      }
    }
    .frame(height: 340)
    .accessibilityHidden(true)
  }
}
