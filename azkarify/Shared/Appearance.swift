import CoreText
import SwiftUI

struct AppAppearance {
  static func accent(_ name: String) -> Color {
    let pair: (light: UIColor, dark: UIColor)
    switch name {
    case "saffron":
      pair = (
        UIColor(red: 0.61, green: 0.30, blue: 0, alpha: 1),
        UIColor(red: 1, green: 0.73, blue: 0.34, alpha: 1)
      )
    case "teal":
      pair = (
        UIColor(red: 0.12, green: 0.39, blue: 0.39, alpha: 1),
        UIColor(red: 0.48, green: 0.87, blue: 0.82, alpha: 1)
      )
    case "blue":
      pair = (
        UIColor(red: 0.16, green: 0.32, blue: 0.59, alpha: 1),
        UIColor(red: 0.57, green: 0.74, blue: 1, alpha: 1)
      )
    case "green":
      pair = (
        UIColor(red: 0.19, green: 0.42, blue: 0.29, alpha: 1),
        UIColor(red: 0.59, green: 0.84, blue: 0.63, alpha: 1)
      )
    default:
      pair = (
        UIColor(red: 0.52, green: 0.25, blue: 0.14, alpha: 1),
        UIColor(red: 0.91, green: 0.62, blue: 0.43, alpha: 1)
      )
    }
    return Color(
      uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? pair.dark : pair.light })
  }

  static func background(_ name: String) -> Color {
    let accentColor = UIColor(accent(name))
    return Color(
      uiColor: UIColor { traits in
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        accentColor.resolvedColor(with: traits).getRed(
          &red, green: &green, blue: &blue, alpha: nil)
        let isDark = traits.userInterfaceStyle == .dark
        let accentWeight: CGFloat = isDark ? 0.10 : 0.04
        let base: CGFloat = isDark ? 0 : 1 - accentWeight
        return UIColor(
          red: base + red * accentWeight,
          green: base + green * accentWeight,
          blue: base + blue * accentWeight,
          alpha: 1)
      })
  }

  static func font(
    size: CGFloat, relativeTo style: Font.TextStyle = .body, bold: Bool = false
  ) -> Font {
    .custom(bold ? "AlanSans-Bold" : "AlanSans-Regular", size: size, relativeTo: style)
  }

  static func registerFonts() {
    if let url = Bundle.main.url(forResource: "AlanSans", withExtension: "ttf") {
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
  }
}

enum AppCopy {
  static func text(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: key, table: "Localizable")
  }

  static func format(_ key: String, _ values: CVarArg...) -> String {
    let language = Bundle.main.preferredLocalizations.first ?? "en"
    return String(format: text(key), locale: Locale(identifier: language), arguments: values)
  }
}
