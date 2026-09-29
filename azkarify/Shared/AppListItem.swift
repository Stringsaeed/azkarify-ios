import SwiftUI

struct AppListItem<Content: View>: View {
  @AppStorage("accent") private var accent = "brown"
  let horizontalPadding: CGFloat
  let verticalPadding: CGFloat
  @ViewBuilder let content: Content

  init(
    horizontalPadding: CGFloat = 16,
    verticalPadding: CGFloat = 16,
    @ViewBuilder content: () -> Content
  ) {
    self.horizontalPadding = horizontalPadding
    self.verticalPadding = verticalPadding
    self.content = content()
  }

  var body: some View {
    content
      .padding(.horizontal, horizontalPadding)
      .padding(.vertical, verticalPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AppAppearance.background(accent), in: RoundedRectangle(cornerRadius: 12))
      .background {
        RoundedRectangle(cornerRadius: 12)
          .fill(AppAppearance.accent(accent))
          .offset(x: 4, y: 4)
      }
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .strokeBorder(AppAppearance.accent(accent).opacity(0.7), lineWidth: 1)
      }
      .padding(.trailing, 4)
      .padding(.bottom, 4)
  }
}
