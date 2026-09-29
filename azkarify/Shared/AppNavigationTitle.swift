import SwiftUI

struct AppNavigationTitle: ViewModifier {
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
                size: 17, relativeTo: .headline,
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
