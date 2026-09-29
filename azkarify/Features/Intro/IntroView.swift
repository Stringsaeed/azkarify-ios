import SwiftUI

struct IntroView: View {
  @EnvironmentObject private var store: AzkarStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("accent") private var accent = "brown"
  @AppStorage("font") private var selectedFont = "ibmPlexSansArabic"
  let onFinish: () -> Void
  @State private var page = 0

  private let pages: [(String, String, String, String, String)] = [
    (
      "📖", "Browse azkar", "تصفح الأذكار", "Find a zikr by topic or search for it.",
      "ابحث عن الذكر بحسب الموضوع أو بالبحث."
    ),
    (
      "text.📖", "Read and reflect", "اقرأ وتدبر",
      "Open a topic to read its azkar or use the slideshow.",
      "افتح موضوعًا لقراءة أذكاره أو استخدم عرض الشرائح."
    ),
    (
      "⭐", "Save favorites", "احفظ المفضلة", "Keep the topics you return to close at hand.",
      "احفظ المواضيع التي تعود إليها كثيرًا."
    ),
    (
      "⚡", "Quick Mode", "الوضع السريع", "Start with morning, evening, sleep, or waking azkar.",
      "ابدأ بأذكار الصباح والمساء أو النوم والاستيقاظ."
    ),
    (
      "📿", "Use the counter", "استخدم السبحة",
      "Tap to count, or count down repeated azkar.", "اضغط للعد أو للعد التنازلي للأذكار المكررة."
    ),
    (
      "🔔", "Set reminders", "اضبط التذكيرات", "Choose morning and evening times in Settings.",
      "اختر أوقات الصباح والمساء من الإعدادات."
    ),
    (
      "🎨", "Make it yours", "خصص التطبيق",
      "Choose Arabic or English, a font, and an accent color.",
      "اختر العربية أو الإنجليزية والخط ولون التمييز."
    ),
    (
      "💛", "Support the app", "ادعم التطبيق",
      "Find ways to support future updates in Settings.",
      "تجد طرق دعم التحديثات القادمة في الإعدادات."
    ),
  ]

  var body: some View {
    VStack(spacing: 20) {
      HStack {
        Spacer()
        Button(AppCopy.text("Skip", "تخطي", language: store.language), action: onFinish)
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
            Text(AppCopy.text(item.1, item.2, language: store.language))
              .font(
                AppAppearance.font(
                  language: store.language, choice: selectedFont, size: 34, relativeTo: .largeTitle,
                  bold: true)
              )
              .multilineTextAlignment(.center)
            Text(AppCopy.text(item.3, item.4, language: store.language))
              .font(
                AppAppearance.font(
                  language: store.language, choice: selectedFont, size: 20, relativeTo: .title3)
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
        AppCopy.text(
          "Page \(page + 1) of \(pages.count)", "الصفحة \(page + 1) من \(pages.count)",
          language: store.language))

      Button {
        if page == pages.count - 1 {
          onFinish()
        } else {
          withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { page += 1 }
        }
      } label: {
        Text(
          page == pages.count - 1
            ? AppCopy.text("Get started", "ابدأ", language: store.language)
            : AppCopy.text("Next", "التالي", language: store.language)
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
