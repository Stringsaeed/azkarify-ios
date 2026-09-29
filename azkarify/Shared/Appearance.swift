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

  static let background = Color(
    uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.14, green: 0.09, blue: 0.07, alpha: 1)
        : UIColor(red: 252 / 255, green: 247 / 255, blue: 240 / 255, alpha: 1)
    })

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
