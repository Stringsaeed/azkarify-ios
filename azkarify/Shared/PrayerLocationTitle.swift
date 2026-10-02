import SwiftUI

struct PrayerLocationTitle: View {
  let title: String
  let language: String
  let location: String?
  let onSelect: () -> Void

  var body: some View {
    Button(action: onSelect) {
      VStack(spacing: 1) {
        Text(title)
          .font(AppAppearance.font(size: 17, relativeTo: .headline, bold: true))
          .lineLimit(1)
        HStack(spacing: 4) {
          Text(location ?? (language == "ar" ? "اختر مدينة" : "Choose a city"))
            .font(AppAppearance.font(size: 12))
            .lineLimit(1)
            .truncationMode(.tail)
          Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
        }
        .frame(maxWidth: 170)
        .padding(.bottom, 4)
        .contentShape(Rectangle())
      }
      .frame(minHeight: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("home.prayerLocation")
    .accessibilityHint(language == "ar" ? "تغيير المدينة" : "Change city")
  }
}
