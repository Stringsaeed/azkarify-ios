import CoreText
import SwiftUI
import UIKit

/// The UI language. The app follows the iOS per-app language, which cannot
/// change while the process runs, so it is read once.
enum AZLocale {
  static let isArabic = Bundle.main.preferredLocalizations.first?.hasPrefix("ar") == true
  static let language = isArabic ? "ar" : "en"
  /// Plain "ar" now formats with Latin digits, so ask for Arabic-Indic numbering explicitly.
  static let locale = Locale(identifier: isArabic ? "ar@numbers=arab" : "en")

  static func text(_ english: String, _ arabic: String) -> String { isArabic ? arabic : english }

  /// Numbers in the UI language (Arabic-Indic digits in Arabic UI).
  static func number(_ value: Int) -> String {
    value.formatted(.number.locale(locale))
  }

  /// "2 / 4" in English and "٢ من ٤" in Arabic, where a slash reorders in RTL.
  static func progress(_ done: Int, of total: Int) -> String {
    isArabic ? "\(number(done)) من \(number(total))" : "\(done) / \(total)"
  }

  /// A counted noun: "1 step" / "8 steps", and in Arabic "خطوة واحدة", "خطوتان", "٨ خطوات", "١٢ خطوة".
  static func count(
    _ value: Int, english: (one: String, other: String),
    arabic: (one: String, two: String, few: String, many: String)
  ) -> String {
    guard isArabic else { return "\(value) \(value == 1 ? english.one : english.other)" }
    switch value {
    case 1: return arabic.one
    case 2: return arabic.two
    case 3...10: return "\(number(value)) \(arabic.few)"
    default: return "\(number(value)) \(arabic.many)"
    }
  }

  static func steps(_ value: Int) -> String {
    count(value, english: ("step", "steps"), arabic: ("خطوة واحدة", "خطوتان", "خطوات", "خطوة"))
  }

  static func times(_ value: Int) -> String {
    count(value, english: ("time", "times"), arabic: ("مرة واحدة", "مرتان", "مرات", "مرة"))
  }

  /// "3 of 24" / "٣ من ٢٤".
  static func position(_ index: Int, of total: Int) -> String {
    isArabic ? "\(number(index)) من \(number(total))" : "\(index) of \(total)"
  }
}

enum AZFont {
  static func registerFonts() {
    let files = ["AlanSans", "SpaceGrotesk-Regular", "SpaceGrotesk-Medium", "SpaceGrotesk-SemiBold"]
    for file in files {
      if let url = Bundle.main.url(forResource: file, withExtension: "ttf") {
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
      }
    }
  }

  static func metrics(_ style: AZTextStyle) -> AZTextStyle.Metrics {
    AZLocale.isArabic ? style.arabic : style.latin
  }

  /// The family follows the UI language: Space Grotesk for English, Alan Sans for Arabic.
  static func font(_ style: AZTextStyle, scale: CGFloat = 1) -> Font {
    let metrics = metrics(style)
    return .custom(metrics.face, size: metrics.size * scale, relativeTo: style.relativeTo)
  }

  static func uiFont(_ style: AZTextStyle) -> UIFont {
    let metrics = metrics(style)
    let base = UIFont(name: metrics.face, size: metrics.size) ?? .systemFont(ofSize: metrics.size)
    return UIFontMetrics(forTextStyle: style.relativeTo.uiTextStyle).scaledFont(for: base)
  }

  private static var naturalLineHeights: [String: CGFloat] = [:]

  /// The extra leading that turns a face's natural line height into the token's line height.
  static func extraLeading(face: String, size: CGFloat, lineHeight: CGFloat) -> CGFloat {
    let key = "\(face)|\(size)"
    let natural: CGFloat
    if let cached = naturalLineHeights[key] {
      natural = cached
    } else {
      natural = UIFont(name: face, size: size)?.lineHeight ?? size * 1.2
      naturalLineHeights[key] = natural
    }
    return max(0, lineHeight - natural)
  }
}

private struct AZTextModifier: ViewModifier {
  let style: AZTextStyle
  let metrics: AZTextStyle.Metrics
  let scale: CGFloat
  @ScaledMetric private var leading: CGFloat

  init(style: AZTextStyle, metrics: AZTextStyle.Metrics, scale: CGFloat) {
    self.style = style
    self.metrics = metrics
    self.scale = scale
    _leading = ScaledMetric(
      wrappedValue: AZFont.extraLeading(
        face: metrics.face, size: metrics.size * scale, lineHeight: metrics.lineHeight * scale),
      relativeTo: style.relativeTo)
  }

  func body(content: Content) -> some View {
    content
      .font(.custom(metrics.face, size: metrics.size * scale, relativeTo: style.relativeTo))
      .tracking(metrics.tracking * scale)
      .lineSpacing(leading)
      .textCase(metrics.uppercase ? .uppercase : nil)
  }
}

extension View {
  /// Applies a design-system text style in the UI language's family.
  func azText(_ style: AZTextStyle, scale: CGFloat = 1) -> some View {
    modifier(AZTextModifier(style: style, metrics: AZFont.metrics(style), scale: scale))
  }

  /// The zikr's Arabic text: Alan Sans in every UI language.
  func azReadingArabic(scale: CGFloat = 1) -> some View {
    modifier(AZTextModifier(style: .readingArabic, metrics: AZTextStyle.readingArabic.arabic, scale: scale))
  }

  /// The English meaning under the Arabic text.
  func azReadingTranslation(scale: CGFloat = 1) -> some View {
    modifier(
      AZTextModifier(style: .readingTranslation, metrics: AZTextStyle.readingTranslation.latin, scale: scale))
  }
}

extension Font.TextStyle {
  var uiTextStyle: UIFont.TextStyle {
    switch self {
    case .largeTitle: .largeTitle
    case .title: .title1
    case .title2: .title2
    case .title3: .title3
    case .headline: .headline
    case .subheadline: .subheadline
    case .callout: .callout
    case .footnote: .footnote
    case .caption: .caption1
    case .caption2: .caption2
    default: .body
    }
  }
}

/// The person's accent. Stored ids predate the design system and stay the same
/// so existing preferences carry over.
enum AZAccent: String, CaseIterable, Identifiable {
  case brown, saffron, teal, blue, green

  var id: String { rawValue }

  init(storedID: String) { self = AZAccent(rawValue: storedID) ?? .brown }

  var color: Color {
    switch self {
    case .brown: AZColor.accentTerracotta
    case .saffron: AZColor.accentEmber
    case .teal: AZColor.accentTeal
    case .blue: AZColor.accentDusk
    case .green: AZColor.accentForest
    }
  }

  var name: String {
    switch self {
    case .brown: AZLocale.text("Terracotta", "قرميدي")
    case .saffron: AZLocale.text("Ember", "جمري")
    case .teal: AZLocale.text("Teal", "فيروزي")
    case .blue: AZLocale.text("Dusk", "شفقي")
    case .green: AZLocale.text("Forest", "أخضر")
    }
  }

  static func color(_ storedID: String) -> Color { AZAccent(storedID: storedID).color }
}

enum AZMotion {
  /// The design system's single curve: ease-out (0.23, 1, 0.32, 1).
  static func curve(_ duration: Double) -> Animation {
    .timingCurve(0.23, 1, 0.32, 1, duration: duration)
  }

  /// Movement becomes a short fade under Reduce Motion.
  static func animation(_ duration: Double, reduceMotion: Bool) -> Animation {
    reduceMotion ? .easeOut(duration: 0.12) : curve(duration)
  }
}

enum AZAppearance {
  /// Native bars keep their platform structure; only their type and colours follow the brand.
  static func configureUIKit() {
    let ink = UIColor(AZColor.ink)
    let navigation = UINavigationBar.appearance()
    navigation.titleTextAttributes = [.font: AZFont.uiFont(.headline), .foregroundColor: ink]
    navigation.largeTitleTextAttributes = [.font: AZFont.uiFont(.title1), .foregroundColor: ink]

    let segmented = UISegmentedControl.appearance()
    let segmentFont = AZFont.uiFont(.callout)
    segmented.setTitleTextAttributes([.font: segmentFont, .foregroundColor: ink], for: .normal)
    segmented.setTitleTextAttributes([.font: segmentFont, .foregroundColor: ink], for: .selected)
    segmented.backgroundColor = UIColor(AZColor.paperSunk)
    segmented.selectedSegmentTintColor = UIColor(AZColor.paperRaised)

    UITabBarItem.appearance().setTitleTextAttributes(
      [.font: AZFont.uiFont(.footnote).withSize(10)], for: .normal)
  }
}
