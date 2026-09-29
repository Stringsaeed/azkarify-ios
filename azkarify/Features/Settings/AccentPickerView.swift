import SwiftUI

struct AccentPickerView: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var selection: String
  let language: String

  private let options: [(id: String, title: String)] = [
    ("brown", "Brown"),
    ("saffron", "Saffron"),
    ("teal", "Teal"),
    ("blue", "Blue"),
    ("green", "Green"),
  ]

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(options, id: \.id) { option in
            Button {
              selection = option.id
              dismiss()
            } label: {
              HStack(spacing: 12) {
                Circle()
                  .fill(AppAppearance.accent(option.id))
                  .frame(width: 24, height: 24)
                  .accessibilityHidden(true)
                Text(AppCopy.text(option.title))
                  .foregroundStyle(.primary)
                Spacer()
                if selection == option.id {
                  Image(systemName: "checkmark")
                    .foregroundStyle(AppAppearance.accent(selection))
                }
              }
              .frame(minHeight: 54)
            }
            .accessibilityAddTraits(selection == option.id ? .isSelected : [])
            if option.id != options.last?.id { Divider() }
          }
        }
        .padding(.horizontal, 20)
      }
      .background(AppAppearance.background(selection))
      .appNavigationTitle(
        AppCopy.text("Accent color"), language: language
      )
      .tint(AppAppearance.accent(selection))
    }
    .presentationDetents([.medium])
    .environment(\.layoutDirection, language == "ar" ? .rightToLeft : .leftToRight)
  }
}
