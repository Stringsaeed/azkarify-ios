import SwiftUI

struct AppNavigationTitle: ViewModifier {
  @AppStorage("font") private var selectedFont = "ibmPlexSansArabic"
  let title: String
  let language: String

  func body(content: Content) -> some View {
    content
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text(title)
            .font(
              AppAppearance.font(
                language: language, choice: selectedFont, size: 17, relativeTo: .headline,
                bold: true)
            )
            .lineLimit(1)
        }
      }
  }
}

extension View {
  func appNavigationTitle(_ title: String, language: String) -> some View {
    modifier(AppNavigationTitle(title: title, language: language))
  }
}
