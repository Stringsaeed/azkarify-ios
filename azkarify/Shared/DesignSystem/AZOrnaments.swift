import SwiftUI

/// The website's ✳ ✦ ☾ ☀ glyphs as vector shapes, drawn on a 24×24 grid.
/// Ornaments are decorative only: never inside buttons, never status.
enum AZOrnamentShape {
  case star, sparkle, crescent, sun
}

struct AZOrnament: View {
  let shape: AZOrnamentShape
  var size: CGFloat = 24
  var color: Color = AZColor.spark
  /// One turn per 18 s; stops under Reduce Motion and off screen.
  var spins = false

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isVisible = false

  var body: some View {
    Group {
      if spins && !reduceMotion && isVisible {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
          let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 18) / 18
          glyph.rotationEffect(.degrees(turn * 360))
        }
      } else {
        glyph
      }
    }
    .frame(width: size, height: size)
    .onAppear { isVisible = true }
    .onDisappear { isVisible = false }
    .accessibilityHidden(true)
    .allowsHitTesting(false)
  }

  @ViewBuilder private var glyph: some View {
    switch shape {
    case .star: StarShape().fill(color)
    case .sparkle: SparkleShape().fill(color)
    case .crescent: CrescentShape().fill(color)
    case .sun: SunShape().fill(color)
    }
  }
}

private extension CGRect {
  /// Maps a point on the 24-unit design grid into this rect.
  func grid(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: minX + x / 24 * width, y: minY + y / 24 * height)
  }

  var gridUnit: CGFloat { min(width, height) / 24 }
}

struct StarShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let unit = rect.gridUnit
    let arm = CGRect(x: rect.midX - 1.9 * unit, y: rect.midY - 11.5 * unit, width: 3.8 * unit, height: 23 * unit)
    let base = Path(roundedRect: arm, cornerRadius: 1.9 * unit)
    for angle in [0.0, 45, 90, 135] {
      let transform = CGAffineTransform(translationX: rect.midX, y: rect.midY)
        .rotated(by: angle * .pi / 180)
        .translatedBy(x: -rect.midX, y: -rect.midY)
      path.addPath(base, transform: transform)
    }
    return path
  }
}

struct SparkleShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: rect.grid(12, 0))
    path.addCurve(to: rect.grid(24, 12), control1: rect.grid(12.8, 7.2), control2: rect.grid(16.8, 11.2))
    path.addCurve(to: rect.grid(12, 24), control1: rect.grid(16.8, 12.8), control2: rect.grid(12.8, 16.8))
    path.addCurve(to: rect.grid(0, 12), control1: rect.grid(11.2, 16.8), control2: rect.grid(7.2, 12.8))
    path.addCurve(to: rect.grid(12, 0), control1: rect.grid(7.2, 11.2), control2: rect.grid(11.2, 7.2))
    path.closeSubpath()
    return path
  }
}

struct CrescentShape: Shape {
  func path(in rect: CGRect) -> Path {
    // The outer disc minus an offset inner disc.
    let unit = rect.gridUnit
    let outer = Path(ellipseIn: CGRect(
      x: rect.minX + 3.62 * unit, y: rect.minY + 1.56 * unit, width: 21.2 * unit, height: 21.2 * unit))
    let inner = Path(ellipseIn: CGRect(
      x: rect.minX + 9.43 * unit, y: rect.minY + 0.88 * unit, width: 18.74 * unit, height: 18.74 * unit))
    return outer.subtracting(inner)
  }
}

struct SunShape: Shape {
  func path(in rect: CGRect) -> Path {
    let unit = rect.gridUnit
    var path = Path(ellipseIn: CGRect(
      x: rect.midX - 5.2 * unit, y: rect.midY - 5.2 * unit, width: 10.4 * unit, height: 10.4 * unit))
    var rays = Path()
    let segments: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
      (12, 1.5, 12, 4.1), (12, 19.9, 12, 22.5), (1.5, 12, 4.1, 12), (19.9, 12, 22.5, 12),
      (4.6, 4.6, 6.4, 6.4), (17.6, 17.6, 19.4, 19.4), (4.6, 19.4, 6.4, 17.6), (17.6, 6.4, 19.4, 4.6),
    ]
    for (x1, y1, x2, y2) in segments {
      rays.move(to: rect.grid(x1, y1))
      rays.addLine(to: rect.grid(x2, y2))
    }
    path.addPath(rays.strokedPath(StrokeStyle(lineWidth: 2.2 * unit, lineCap: .round)))
    return path
  }
}

/// The website's arch frame for hero art: a `clay` arch with two hairline insets.
struct AZJourneyArch<Content: View>: View {
  var width: CGFloat = 150
  var height: CGFloat = 200
  @ViewBuilder var content: Content

  var body: some View {
    let shape = archShape(inset: 0)
    ZStack {
      shape.fill(AZColor.clay)
      archShape(inset: 8).stroke(AZColor.ink.opacity(0.25), lineWidth: AZBorder.hairline)
      archShape(inset: 16).stroke(AZColor.ink.opacity(0.18), lineWidth: AZBorder.hairline)
      content
    }
    .frame(width: width, height: height)
    .accessibilityHidden(true)
  }

  private func archShape(inset: CGFloat) -> some Shape {
    UnevenRoundedRectangle(
      topLeadingRadius: width / 2 - inset, bottomLeadingRadius: max(AZRadius.lg - inset, 4),
      bottomTrailingRadius: max(AZRadius.lg - inset, 4), topTrailingRadius: width / 2 - inset
    )
    .inset(by: inset)
  }
}
