import Foundation

enum AppCopy {
  static func text(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: key, table: "Localizable")
  }

  static func format(_ key: String, _ values: CVarArg...) -> String {
    let language = Bundle.main.preferredLocalizations.first ?? "en"
    return String(format: text(key), locale: Locale(identifier: language), arguments: values)
  }
}
