import SwiftUI

struct QuickModeView: View {
  @EnvironmentObject private var store: AzkarStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("accent") private var accent = "brown"
  @State private var selectedID = 27
  private let presets: [(Int, String, String, String)] = [
    (27, "Morning & Evening", "الصباح والمساء", "🌅"),
    (28, "Before Sleep", "قبل النوم", "🌙"),
    (1, "Upon Waking", "عند الاستيقاظ", "☀️"),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(
        AppCopy.text(
          "Choose a set to start counting with one tap.", "اختر مجموعة لبدء العد بلمسة واحدة.",
          language: store.language)
      )
      .padding(.horizontal, 16)
      ScrollView(.horizontal) {
        HStack(spacing: 12) {
          ForEach(presets, id: \.0) { id, english, arabic, emoji in
            Button {
              withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) { selectedID = id }
            } label: {
              Text("\(emoji) " + AppCopy.text(english, arabic, language: store.language))
                .padding(16)
                .frame(minHeight: 44)
                .background(
                  selectedID == id
                    ? AppAppearance.accent(accent).opacity(0.18) : Color.secondary.opacity(0.08),
                  in: RoundedRectangle(cornerRadius: 16))
            }
            .accessibilityAddTraits(selectedID == id ? .isSelected : [])
          }
        }.padding(.horizontal, 16)
      }
      if let category = store.categories.first(where: { $0.id == selectedID }) {
        ZikrListView(category: category)
          .id(selectedID)
      }
    }
    .padding(.top, 16)
    .background(AppAppearance.background)
    .appNavigationTitle(
      AppCopy.text("Quick Mode", "الوضع السريع", language: store.language), language: store.language
    )
  }
}
