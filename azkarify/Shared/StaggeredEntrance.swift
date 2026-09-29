import SwiftUI

struct StaggeredEntrance: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let index: Int
  @State private var visible = false

  func body(content: Content) -> some View {
    content
      .opacity(visible || reduceMotion || index >= 8 ? 1 : 0)
      .offset(y: visible || reduceMotion || index >= 8 ? 0 : 8)
      .onAppear {
        guard !visible else { return }
        if reduceMotion || index >= 8 {
          visible = true
        } else {
          withAnimation(.easeOut(duration: 0.25).delay(Double(index) * 0.035)) {
            visible = true
          }
        }
      }
  }
}
