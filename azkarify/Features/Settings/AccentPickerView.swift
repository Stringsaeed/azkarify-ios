import SwiftUI

struct AccentPickerView: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var selection: String
  let language: String

  private let options: [(id: String, english: String, arabic: String)] = [
    ("brown", "Brown", "بني"),
    ("saffron", "Saffron", "زعفراني"),
    ("teal", "Teal", "فيروزي"),
    ("blue", "Blue", "أزرق"),
    ("green", "Green", "أخضر"),
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
                Text(AppCopy.text(option.english, option.arabic, language: language))
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
      .background(AppAppearance.background)
      .appNavigationTitle(
        AppCopy.text("Accent color", "لون التمييز", language: language), language: language
      )
      .tint(AppAppearance.accent(selection))
    }
    .presentationDetents([.medium])
    .environment(\.layoutDirection, language == "ar" ? .rightToLeft : .leftToRight)
  }
}
