import SwiftUI

private struct ContentHeightPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

/// Gives a content-driven sheet a single detent while keeping long content
/// scrollable. The modifier belongs inside the sheet content so it can
/// override detents supplied by the presenting view.
struct ContentSizedSheet: ViewModifier {
  let maximumHeightFraction: CGFloat
  let minimumHeight: CGFloat
  @State private var contentHeight: CGFloat = 0

  private var maximumHeight: CGFloat {
    let scene = UIApplication.shared.connectedScenes
      .first { $0.activationState == .foregroundActive } as? UIWindowScene
    return (scene?.screen.bounds.height ?? 800) * maximumHeightFraction
  }

  private var detentHeight: CGFloat {
    min(max(contentHeight, minimumHeight), maximumHeight)
  }

  func body(content: Content) -> some View {
    content
      .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
        guard height > 0 else { return }
        contentHeight = height
      }
      .presentationDetents([.height(detentHeight)])
      .presentationDragIndicator(.visible)
  }
}

extension View {
  func contentSizedSheet(
    maximumHeightFraction: CGFloat = 0.85,
    minimumHeight: CGFloat = 260
  ) -> some View {
    modifier(ContentSizedSheet(
      maximumHeightFraction: maximumHeightFraction,
      minimumHeight: minimumHeight))
  }
}

extension View {
  /// Measures the rendered content of a sheet rather than the viewport of a
  /// surrounding ScrollView. This keeps the detent responsive to copy,
  /// Dynamic Type, and the city/country view transition.
  func sheetContentHeight() -> some View {
    background {
      GeometryReader { proxy in
        Color.clear.preference(
          key: ContentHeightPreferenceKey.self,
          value: proxy.size.height)
      }
    }
  }
}
