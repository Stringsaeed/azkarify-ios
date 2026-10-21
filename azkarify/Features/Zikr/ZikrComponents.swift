import SwiftUI

enum ReaderSettings {
  static let scaleKey = "reader.textScale"
  static let transliterationKey = "reader.showTransliteration"
  static let scales: [Double] = [0.85, 1, 1.15, 1.3, 1.5]

  static func step(_ scale: Double, by offset: Int) -> Double {
    let index = scales.firstIndex { abs($0 - scale) < 0.01 } ?? 1
    return scales[min(max(index + offset, 0), scales.count - 1)]
  }

  static func label(_ scale: Double) -> String {
    abs(scale - 1) < 0.01 ? AZLocale.text("Default", "افتراضي") : (scale * 100).formatted(
      .number.precision(.fractionLength(0)).locale(AZLocale.locale)) + "%"
  }
}

/// The repetition count on a zikr: tap to open the counter already set to that number.
struct CountButton: View {
  let count: Int
  let action: () -> Void

  var body: some View {
    let shape = Capsule()
    Button(action: action) {
      HStack(spacing: 8) {
        Text("×")
          .font(.custom(AZLocale.isArabic ? "AlanSans-SemiBold" : "SpaceGrotesk-SemiBold", size: 13))
          .foregroundStyle(AZColor.paper)
          .frame(width: 28, height: 28)
          .background(AZColor.ink, in: Circle())
        Text(AZLocale.text(count == 1 ? "1 time" : "\(count) times", "\(AZLocale.number(count)) مرات"))
          .azText(.headline, scale: 15.0 / 17.0)
          .monospacedDigit()
      }
      .foregroundStyle(AZColor.ink)
      .padding(.leading, 6)
      .padding(.trailing, 14)
      .frame(height: 40)
      .background(AZColor.peach, in: shape)
      .overlay { shape.strokeBorder(.azStampOutline, lineWidth: AZBorder.hairline) }
    }
    .buttonStyle(AZPressableCardStyle(stamp: AZStamp.sm, radius: 20))
    .frame(minHeight: 44)
    .accessibilityLabel(AZLocale.text("Count down from \(count)", "العد التنازلي من \(AZLocale.number(count))"))
  }
}

/// One zikr in the reader: the Arabic, then (English UI) the meaning, then its position and count.
struct ZikrCard: View {
  let entry: ZikrEntry
  let index: Int
  let total: Int
  var scale: Double = 1
  var showsTransliteration = false
  let onCount: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: AZSpace.sm + 2) {
      Text(entry.text.arabic)
        .azReadingArabic(scale: scale)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, .rightToLeft)
        .textSelection(.enabled)
      if showsTransliteration && !entry.text.arabicTranslated.isEmpty {
        Text(entry.text.arabicTranslated)
          .azText(.callout)
          .italic()
          .foregroundStyle(AZColor.inkMuted)
          .textSelection(.enabled)
      }
      if !AZLocale.isArabic && !entry.text.translated.isEmpty {
        Text(entry.text.translated)
          .azReadingTranslation(scale: scale)
          .foregroundStyle(AZColor.ink)
          .textSelection(.enabled)
      }
      HStack(spacing: AZSpace.sm) {
        Text(AZLocale.position(index + 1, of: total))
          .azText(.footnote)
          .monospacedDigit()
          .foregroundStyle(AZColor.inkMuted)
        Spacer(minLength: 0)
        if entry.repeat > 1 {
          CountButton(count: entry.repeat, action: onCount)
        }
      }
      .frame(minHeight: 44)
      .padding(.top, AZSpace.sm)
      .overlay(alignment: .top) { Rectangle().fill(AZColor.line).frame(height: AZBorder.hairline) }
    }
    .padding(.horizontal, AZSpace.lg)
    .padding(.top, 22)
    .padding(.bottom, AZSpace.md)
    .foregroundStyle(AZColor.ink)
    .background(AZColor.paperRaised, in: RoundedRectangle(cornerRadius: AZRadius.lg, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: AZRadius.lg, style: .continuous)
        .strokeBorder(AZColor.lineStrong, lineWidth: AZBorder.hairline)
    }
  }
}

/// Smaller / larger reading text, remembered across launches.
struct ReaderSizeMenu: View {
  @AppStorage(ReaderSettings.scaleKey) private var scale = 1.0

  var body: some View {
    Menu {
      ControlGroup {
        Button {
          scale = ReaderSettings.step(scale, by: -1)
        } label: {
          Label(AZLocale.text("Smaller", "أصغر"), systemImage: "textformat.size.smaller")
        }
        .disabled(scale <= ReaderSettings.scales.first!)
        Button {
          scale = ReaderSettings.step(scale, by: 1)
        } label: {
          Label(AZLocale.text("Larger", "أكبر"), systemImage: "textformat.size.larger")
        }
        .disabled(scale >= ReaderSettings.scales.last!)
      }
      Button(AZLocale.text("Reset text size", "إعادة حجم النص")) { scale = 1 }
        .disabled(abs(scale - 1) < 0.01)
    } label: {
      Image(systemName: "textformat.size")
    }
    .menuActionDismissBehavior(.disabled)
    .accessibilityLabel(AZLocale.text("Text size", "حجم النص"))
    .accessibilityValue(ReaderSettings.label(scale))
  }
}
