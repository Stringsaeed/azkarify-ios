import SwiftUI
import UIKit

// MARK: - Stamp

/// The website's hard offset shadow. Never blurred; the x offset mirrors in RTL.
private struct AZStampModifier<S: InsettableShape>: ViewModifier {
  let shape: S
  let offset: CGSize
  var isPressed = false
  @Environment(\.layoutDirection) private var layoutDirection

  func body(content: Content) -> some View {
    let x = layoutDirection == .rightToLeft ? -offset.width : offset.width
    content
      .background {
        shape.fill(AZColor.stampShadow)
          .offset(x: isPressed ? 0 : x, y: isPressed ? 0 : offset.height)
      }
      .offset(x: isPressed ? x : 0, y: isPressed ? offset.height : 0)
  }
}

extension View {
  func azStamp<S: InsettableShape>(_ offset: CGSize, shape: S, isPressed: Bool = false) -> some View {
    modifier(AZStampModifier(shape: shape, offset: offset, isPressed: isPressed))
  }
}

/// Stamped outlines use `ink` by day and `line-strong` at night.
struct AZStampOutline: ShapeStyle {
  func resolve(in environment: EnvironmentValues) -> Color {
    environment.colorScheme == .dark ? AZColor.lineStrong : AZColor.ink
  }
}

extension ShapeStyle where Self == AZStampOutline {
  static var azStampOutline: AZStampOutline { AZStampOutline() }
}

// MARK: - Buttons

enum AZButtonVariant {
  case primary, secondary, accent, text
}

struct AZButtonStyle: ButtonStyle {
  var variant: AZButtonVariant = .primary
  var small = false
  var fullWidth = false

  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    let shape = Capsule()
    let pressed = configuration.isPressed
    configuration.label
      .azText(.button, scale: small ? 15.0 / 16.0 : 1)
      .lineLimit(2)
      .multilineTextAlignment(.center)
      .padding(.horizontal, variant == .text ? 12 : (small ? 16 : 24))
      .frame(minHeight: variant == .text ? 44 : (small ? 40 : 52))
      .frame(maxWidth: fullWidth ? .infinity : nil)
      .foregroundStyle(foreground)
      .background {
        switch variant {
        case .primary: shape.fill(AZColor.ink)
        case .secondary: shape.fill(AZColor.paperRaised)
        case .accent: shape.fill(.tint)
        case .text: Color.clear
        }
      }
      .overlay {
        if variant == .secondary { shape.strokeBorder(.azStampOutline, lineWidth: AZBorder.hairline) }
      }
      .contentShape(shape)
      .modifier(SecondaryStamp(enabled: variant == .secondary, pressed: pressed))
      .scaleEffect(variant == .primary || variant == .accent ? (pressed ? 0.985 : 1) : 1)
      .opacity(isEnabled ? 1 : 0.4)
      .animation(reduceMotion ? nil : AZMotion.curve(AZDuration.press), value: pressed)
      .sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, new in new }
  }

  private var foreground: AnyShapeStyle {
    switch variant {
    case .primary: AnyShapeStyle(AZColor.paper)
    case .secondary: AnyShapeStyle(AZColor.ink)
    case .accent: AnyShapeStyle(AZColor.onAccent)
    case .text: AnyShapeStyle(.tint)
    }
  }

  private struct SecondaryStamp: ViewModifier {
    let enabled: Bool
    let pressed: Bool

    func body(content: Content) -> some View {
      if enabled {
        content.azStamp(AZStamp.sm, shape: Capsule(), isPressed: pressed)
      } else {
        content
      }
    }
  }
}

extension ButtonStyle where Self == AZButtonStyle {
  static var azPrimary: AZButtonStyle { AZButtonStyle(variant: .primary) }
  static var azSecondary: AZButtonStyle { AZButtonStyle(variant: .secondary) }
  static var azAccent: AZButtonStyle { AZButtonStyle(variant: .accent) }
  static var azText: AZButtonStyle { AZButtonStyle(variant: .text) }

  static func az(_ variant: AZButtonVariant, small: Bool = false, fullWidth: Bool = false) -> AZButtonStyle {
    AZButtonStyle(variant: variant, small: small, fullWidth: fullWidth)
  }
}

enum AZIconButtonVariant {
  case plain, filled, outline, ink
}

/// A 44pt circular button for one symbol on custom surfaces.
struct AZIconButtonStyle: ButtonStyle {
  var variant: AZIconButtonVariant = .filled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 18, weight: .medium))
      .foregroundStyle(variant == .ink ? AZColor.paper : AZColor.ink)
      .frame(width: 44, height: 44)
      .background {
        switch variant {
        case .plain: Color.clear
        case .filled: Circle().fill(AZColor.paperSunk)
        case .outline: Circle().fill(AZColor.paperRaised)
        case .ink: Circle().fill(AZColor.ink)
        }
      }
      .overlay {
        if variant == .outline { Circle().strokeBorder(.azStampOutline, lineWidth: AZBorder.hairline) }
      }
      .contentShape(Circle())
      .opacity(configuration.isPressed ? 0.6 : 1)
  }
}

extension ButtonStyle where Self == AZIconButtonStyle {
  static func azIcon(_ variant: AZIconButtonVariant = .filled) -> AZIconButtonStyle {
    AZIconButtonStyle(variant: variant)
  }
}

/// A stamped card that is one button: pressed, it moves by its offset and loses its shadow.
struct AZPressableCardStyle: ButtonStyle {
  var stamp: CGSize? = nil
  var radius: CGFloat = AZRadius.lg

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    let pressed = configuration.isPressed
    Group {
      if let stamp {
        configuration.label
          .azStamp(stamp, shape: RoundedRectangle(cornerRadius: radius, style: .continuous), isPressed: pressed)
      } else {
        configuration.label.opacity(pressed ? 0.75 : 1)
      }
    }
    .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    .animation(reduceMotion ? nil : AZMotion.curve(AZDuration.press), value: pressed)
    .sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, new in new && stamp != nil }
  }
}

// MARK: - Cards

enum AZCardTone {
  case quiet, sage, peach, lime, clay, mist, sunk, forest

  var fill: Color {
    switch self {
    case .quiet: AZColor.paperRaised
    case .sage: AZColor.sage
    case .peach: AZColor.peach
    case .lime: AZColor.lime
    case .clay: AZColor.clay
    case .mist: AZColor.mist
    case .sunk: AZColor.paperSunk
    case .forest: AZColor.forest
    }
  }

  var border: Color {
    switch self {
    case .quiet: AZColor.lineStrong
    case .sage, .peach: AZColor.ink.opacity(0.22)
    case .sunk: AZColor.line
    case .forest: AZColor.forest
    case .lime, .clay, .mist: AZColor.lineStrong
    }
  }

  /// Secondary text on this surface.
  var secondaryText: Color {
    switch self {
    case .quiet, .sunk: AZColor.inkMuted
    case .forest: AZColor.onForest.opacity(0.82)
    default: AZColor.inkSoft
    }
  }

  var text: Color { self == .forest ? AZColor.onForest : AZColor.ink }
}

private struct AZCardModifier: ViewModifier {
  let tone: AZCardTone
  let compact: Bool
  let stamped: Bool
  let padding: CGFloat?

  func body(content: Content) -> some View {
    let radius = compact ? AZRadius.md : AZRadius.lg
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    content
      .padding(padding ?? (compact ? AZSpace.md : AZSpace.lg))
      .frame(maxWidth: .infinity, alignment: .leading)
      .foregroundStyle(tone.text)
      .background(tone.fill, in: shape)
      .overlay {
        if stamped {
          shape.strokeBorder(.azStampOutline, lineWidth: AZBorder.hairline)
        } else {
          shape.strokeBorder(tone.border, lineWidth: AZBorder.hairline)
        }
      }
  }
}

extension View {
  /// Quiet (outlined), toned (a moment pastel) or, with `stamped`, the outline for the screen's one
  /// interactive hero. Add the stamp shadow with `AZPressableCardStyle(stamp:)` or `azStamp`.
  func azCard(
    _ tone: AZCardTone = .quiet, compact: Bool = false, stamped: Bool = false, padding: CGFloat? = nil
  ) -> some View {
    modifier(AZCardModifier(tone: tone, compact: compact, stamped: stamped, padding: padding))
  }

  /// The screen background: `paper`, never pure white or black.
  func azScreenBackground() -> some View {
    background(AZColor.paper.ignoresSafeArea())
  }
}

// MARK: - Small pieces

enum AZWellState {
  case idle, on, spark, lime
}

/// A 44pt circle holding one symbol. Decorative: the row's label says what it is.
struct AZIconWell: View {
  let systemImage: String
  var state: AZWellState = .idle
  var size: CGFloat = 44

  var body: some View {
    Image(systemName: systemImage)
      .font(.system(size: size >= 44 ? 20 : 17, weight: .regular))
      .symbolRenderingMode(.monochrome)
      .foregroundStyle(foreground)
      .frame(width: size, height: size)
      .background(background, in: Circle())
      .overlay {
        if state == .lime { Circle().strokeBorder(.azStampOutline, lineWidth: AZBorder.hairline) }
      }
      .accessibilityHidden(true)
  }

  private var foreground: Color {
    switch state {
    case .on: AZColor.onForest
    case .spark: Color(uiColor: UIColor(hex: 0x252923))
    default: AZColor.ink
    }
  }

  private var background: Color {
    switch state {
    case .idle: AZColor.paperSunk
    case .on: AZColor.forest
    case .spark: AZColor.spark
    case .lime: AZColor.lime
    }
  }
}

/// An 8pt pill track. Always pair it with text; RTL fills from the right.
struct AZProgressTrack: View {
  let value: Double
  var complete = false
  var onPastel = false
  var height: CGFloat = 8

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Capsule()
      .fill(onPastel ? AZColor.paper.opacity(0.6) : AZColor.paperSunk)
      .overlay(alignment: .leading) {
        GeometryReader { proxy in
          Capsule()
            .fill(complete ? AnyShapeStyle(AZColor.forest) : AnyShapeStyle(.tint))
            .frame(width: proxy.size.width * min(max(value, 0), 1))
        }
      }
      .clipShape(Capsule())
      .frame(height: height)
      .animation(reduceMotion ? nil : AZMotion.curve(AZDuration.slow), value: value)
      .accessibilityHidden(true)
  }
}

enum AZPillTone {
  case accent, muted, solid
}

/// A small outlined tag. Never interactive.
struct AZPill: View {
  let label: String
  var tone: AZPillTone = .accent

  var body: some View {
    Text(label)
      .font(AZLocale.isArabic
            ? .custom("AlanSans-SemiBold", size: 12, relativeTo: .caption)
            : .custom("SpaceGrotesk-SemiBold", size: 11, relativeTo: .caption2))
      .tracking(AZLocale.isArabic ? 0 : 0.66)
      .textCase(AZLocale.isArabic ? nil : .uppercase)
      .lineLimit(1)
      .padding(.horizontal, 10)
      .frame(minHeight: 24)
      .foregroundStyle(foreground)
      .background {
        if tone == .solid { Capsule().fill(AZColor.ink) }
      }
      .overlay {
        Capsule().strokeBorder(tone == .solid ? AnyShapeStyle(AZColor.ink) : foreground, lineWidth: AZBorder.hairline)
      }
  }

  private var foreground: AnyShapeStyle {
    switch tone {
    case .accent: AnyShapeStyle(.tint)
    case .muted: AnyShapeStyle(AZColor.inkMuted)
    case .solid: AnyShapeStyle(AZColor.paper)
    }
  }
}

/// The website's tilted lime sticker: the one thing that is next or newly done.
struct AZSticker<Leading: View>: View {
  let label: String
  var large = false
  var tilted = true
  @ViewBuilder var leading: Leading

  @Environment(\.layoutDirection) private var layoutDirection

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: AZRadius.xs, style: .continuous)
    let angle = (large ? -8.0 : -4.0) * (layoutDirection == .rightToLeft ? -1 : 1)
    HStack(spacing: 8) {
      leading
      Text(label)
        .font(AZLocale.isArabic
              ? .custom("AlanSans-SemiBold", size: large ? 20 : 14, relativeTo: large ? .title3 : .subheadline)
              : .custom("SpaceGrotesk-SemiBold", size: large ? 20 : 14, relativeTo: large ? .title3 : .subheadline))
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .foregroundStyle(AZColor.ink)
    .padding(.horizontal, large ? 18 : 14)
    .padding(.top, large ? 16 : 8)
    .padding(.bottom, large ? 13 : 7)
    .background(AZColor.lime, in: shape)
    .overlay { shape.strokeBorder(.azStampOutline, lineWidth: AZBorder.stamp) }
    .azStamp(large ? CGSize(width: 4, height: 4) : AZStamp.sm, shape: shape)
    .rotationEffect(.degrees(tilted ? angle : 0))
  }
}

extension AZSticker where Leading == EmptyView {
  init(label: String, large: Bool = false, tilted: Bool = true) {
    self.init(label: label, large: large, tilted: tilted) { EmptyView() }
  }
}

/// The points total in a toolbar. Replaces the mosaic-coin button.
struct AZPointsBadge: View {
  let points: Int

  var body: some View {
    HStack(spacing: 6) {
      AZOrnament(shape: .star, size: 16, color: AZColor.spark)
      Text(AZLocale.number(points))
        .azText(.headline)
        .monospacedDigit()
        .contentTransition(.numericText(value: Double(points)))
        .lineLimit(1)
    }
    // Toolbars propose a narrow width; the score must never truncate.
    .fixedSize()
    .foregroundStyle(AZColor.ink)
    .padding(.leading, 8)
    .padding(.trailing, 12)
    .frame(height: 36)
    .background(AZColor.paperRaised, in: Capsule())
    .overlay { Capsule().strokeBorder(.azStampOutline, lineWidth: AZBorder.hairline) }
    .frame(minHeight: 44)
  }
}

/// Eyebrow + title + optional trailing action above a group.
struct AZSectionHeader<Action: View>: View {
  var eyebrow: String?
  let title: String
  @ViewBuilder var action: Action

  var body: some View {
    HStack(alignment: .lastTextBaseline, spacing: AZSpace.sm) {
      VStack(alignment: .leading, spacing: 4) {
        if let eyebrow {
          Text(eyebrow).azText(.eyebrow).foregroundStyle(AZColor.sparkInk)
        }
        Text(title)
          .azText(.title3)
          .foregroundStyle(AZColor.ink)
          .accessibilityAddTraits(.isHeader)
      }
      Spacer(minLength: 0)
      action
        .azText(.headline, scale: 15.0 / 17.0)
        .frame(minHeight: 44)
    }
  }
}

extension AZSectionHeader where Action == EmptyView {
  init(eyebrow: String? = nil, title: String) {
    self.init(eyebrow: eyebrow, title: title) { EmptyView() }
  }
}

/// A pill-shaped choice for quick filters. Selected is ink, never accent.
struct AZChip: View {
  let title: String
  var systemImage: String?
  var isSelected = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if let systemImage {
          Image(systemName: systemImage).font(.system(size: 16)).accessibilityHidden(true)
        }
        Text(title).azText(.rowTitle, scale: 15.0 / 16.0).lineLimit(1)
      }
      .padding(.horizontal, 14)
      .frame(height: 40)
      .foregroundStyle(isSelected ? AZColor.paper : AZColor.ink)
      .background(isSelected ? AZColor.ink : AZColor.paperRaised, in: Capsule())
      .overlay {
        Capsule().strokeBorder(isSelected ? AZColor.ink : AZColor.lineStrong, lineWidth: AZBorder.hairline)
      }
      .contentShape(Capsule())
      .frame(minHeight: 44)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

/// Page dots: the active one is a `spark` pill.
struct AZPageDots: View {
  let count: Int
  let index: Int

  var body: some View {
    HStack(spacing: 6) {
      ForEach(0..<count, id: \.self) { item in
        Capsule()
          .fill(item == index ? AZColor.spark : AZColor.lineStrong)
          .frame(width: item == index ? 18 : 6, height: 6)
      }
    }
    .animation(AZMotion.curve(AZDuration.base), value: index)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AZLocale.text("Page \(index + 1) of \(count)",
                                      "الصفحة \(AZLocale.number(index + 1)) من \(AZLocale.number(count))"))
  }
}

/// What a screen shows with nothing to list.
struct AZEmptyState<Art: View, Actions: View>: View {
  let title: String
  var message: String?
  @ViewBuilder var art: Art
  @ViewBuilder var actions: Actions

  var body: some View {
    VStack(spacing: AZSpace.sm) {
      art.frame(height: 56)
      Text(title).azText(.title3).foregroundStyle(AZColor.ink).multilineTextAlignment(.center)
      if let message {
        Text(message).azText(.body).foregroundStyle(AZColor.inkMuted).multilineTextAlignment(.center)
      }
      actions.padding(.top, AZSpace.xs)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, AZSpace.xxl)
    .padding(.horizontal, AZSpace.lg)
    .accessibilityElement(children: .contain)
  }
}

extension AZEmptyState where Actions == EmptyView {
  init(title: String, message: String? = nil, @ViewBuilder art: () -> Art) {
    self.init(title: title, message: message, art: art) { EmptyView() }
  }
}

// MARK: - Grouped lists

/// A rounded group of rows separated by hairlines, for short lists on brand screens.
/// Long lists (the Hisn) use a styled `List` instead.
struct AZListGroup<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    VStack(spacing: 0) {
      Group(subviews: content) { rows in
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
          if index > 0 {
            Rectangle().fill(AZColor.line).frame(height: AZBorder.hairline)
              .padding(.leading, AZSpace.md)
          }
          row
        }
      }
    }
    .background(AZColor.paperRaised, in: RoundedRectangle(cornerRadius: AZRadius.md, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: AZRadius.md, style: .continuous)
        .strokeBorder(AZColor.lineStrong, lineWidth: AZBorder.hairline)
    }
    .clipShape(RoundedRectangle(cornerRadius: AZRadius.md, style: .continuous))
  }
}

/// A list row: optional leading content, a title, an optional subtitle and one trailing accessory.
struct AZListRow<Leading: View, Trailing: View>: View {
  let title: String
  var subtitle: String?
  /// Shows the subtitle above the title, as a label ("Country" over "United Arab Emirates").
  var subtitleFirst = false
  @ViewBuilder var leading: Leading
  @ViewBuilder var trailing: Trailing

  var body: some View {
    HStack(spacing: AZSpace.sm) {
      leading
      VStack(alignment: .leading, spacing: 2) {
        if subtitleFirst, let subtitle { subtitleText(subtitle) }
        Text(title).azText(.rowTitle).foregroundStyle(AZColor.ink).multilineTextAlignment(.leading)
        if !subtitleFirst, let subtitle { subtitleText(subtitle) }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      trailing
    }
    .padding(.horizontal, AZSpace.md)
    .padding(.vertical, 10)
    .frame(minHeight: 56)
    .contentShape(Rectangle())
  }

  private func subtitleText(_ text: String) -> some View {
    Text(text).azText(.footnote).foregroundStyle(AZColor.inkMuted).multilineTextAlignment(.leading)
  }
}

extension AZListRow where Leading == EmptyView {
  init(title: String, subtitle: String? = nil, subtitleFirst: Bool = false, @ViewBuilder trailing: () -> Trailing) {
    self.init(title: title, subtitle: subtitle, subtitleFirst: subtitleFirst, leading: { EmptyView() }, trailing: trailing)
  }
}

/// A trailing chevron that mirrors in RTL.
struct AZChevron: View {
  var body: some View {
    Image(systemName: "chevron.forward")
      .font(.system(size: 14, weight: .semibold))
      .foregroundStyle(AZColor.inkSubtle)
      .accessibilityHidden(true)
  }
}

// MARK: - Forms

extension View {
  /// Native `Form`/`List` on the brand ground: `paper` behind, brand type.
  func azFormStyle() -> some View {
    scrollContentBackground(.hidden)
      .background(AZColor.paper.ignoresSafeArea())
      .font(AZFont.font(.body))
      .foregroundStyle(AZColor.ink)
  }

  /// Rows on `paper-raised` inside a form.
  func azFormRow() -> some View {
    listRowBackground(AZColor.paperRaised)
  }
}

/// A form section header: `eyebrow` in `ink-muted`.
struct AZFormHeader: View {
  let title: String

  var body: some View {
    Text(title).azText(.eyebrow).foregroundStyle(AZColor.inkMuted)
  }
}
