import ConfettiSwiftUI
import SwiftUI

struct ConfettiBurst: ViewModifier {
  @Binding var token: Int
  let accent: String
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    content.confettiCannon(
      trigger: reduceMotion ? .constant(0) : $token,
      num: 40,
      colors: [
        AppAppearance.accent(accent),
        AppAppearance.accent("saffron"),
        AppAppearance.accent("teal"),
        AppAppearance.accent("green"),
        .white,
      ],
      hapticFeedback: !reduceMotion
    )
  }
}

extension View {
  func confettiBurst(token: Binding<Int>, accent: String) -> some View {
    modifier(ConfettiBurst(token: token, accent: accent))
  }
}
