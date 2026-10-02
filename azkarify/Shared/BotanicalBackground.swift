import SwiftUI

struct BotanicalBackground: View {
  let accent: String
  var variant: Int = 0

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.layoutDirection) private var layoutDirection
  @Environment(\.colorScheme) private var colorScheme
  @State private var appeared = false

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        AppAppearance.background(accent)

        ForEach(0..<6) { index in
          let left = index.isMultiple(of: 2)
          let mirroredLeft = layoutDirection == .rightToLeft ? !left : left
          let size = CGFloat(112 + variation(index, salt: 3) * 34)
          let y = geometry.size.height * CGFloat(
            0.10 + Double(index / 2) * 0.35 + variation(index, salt: 7) * 0.09)

          BotanicalSprig(accent: accent)
            .frame(width: size, height: size * 1.8)
            .scaleEffect(x: mirroredLeft ? 1 : -1, y: 1)
            .rotationEffect(.degrees((mirroredLeft ? 1 : -1) *
              (12 + variation(index, salt: 11) * 18)))
            .opacity(colorScheme == .dark ? 0.15 : 0.12)
            .position(x: mirroredLeft ? 4 : geometry.size.width - 4, y: y)
            .offset(x: appeared || reduceMotion ? 0 : (mirroredLeft ? -50 : 50))
            .opacity(appeared || reduceMotion ? 1 : 0)
            .animation(
              reduceMotion ? nil : .easeOut(duration: 0.9).delay(Double(index) * 0.075),
              value: appeared)
        }
      }
      .clipped()
    }
    .ignoresSafeArea()
    .accessibilityHidden(true)
    .allowsHitTesting(false)
    .onAppear { appeared = true }
  }

  private func variation(_ index: Int, salt: Int) -> Double {
    let seed = UInt64(truncatingIfNeeded: variant) &* 2_654_435_761
      &+ UInt64(index * 97 + salt * 31)
    let mixed = (seed ^ (seed >> 13)) &* 1_274_126_177
    return Double(mixed % 1_000) / 1_000
  }
}

private struct BotanicalSprig: View {
  let accent: String

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        BotanicalStem()
          .stroke(AppAppearance.accent(accent), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

        ForEach(0..<7) { index in
          let left = index.isMultiple(of: 2)
          let height = geometry.size.height * (index == 6 ? 0.20 : 0.25)
          let width = geometry.size.width * 0.30
          BotanicalLeaf()
            .fill(LinearGradient(
              colors: [AppAppearance.accent(accent).opacity(0.65), AppAppearance.accent(accent)],
              startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: width, height: height)
            .rotationEffect(.degrees(index == 6 ? -8 : (left ? -52 : 48)))
            .position(
              x: geometry.size.width * (index == 6 ? 0.44 : (left ? 0.32 : 0.68)),
              y: geometry.size.height * (0.85 - Double(index) * 0.115))
        }
      }
    }
  }
}

private struct BotanicalStem: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.width * 0.60, y: rect.height))
    path.addCurve(
      to: CGPoint(x: rect.width * 0.44, y: rect.height * 0.05),
      control1: CGPoint(x: rect.width * 0.46, y: rect.height * 0.66),
      control2: CGPoint(x: rect.width * 0.60, y: rect.height * 0.31))
    return path
  }
}

private struct BotanicalLeaf: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
    path.addCurve(
      to: CGPoint(x: rect.width * 0.43, y: rect.minY),
      control1: CGPoint(x: -rect.width * 0.16, y: rect.height * 0.68),
      control2: CGPoint(x: rect.width * 0.08, y: rect.height * 0.27))
    path.addCurve(
      to: CGPoint(x: rect.midX, y: rect.maxY),
      control1: CGPoint(x: rect.width * 1.03, y: rect.height * 0.25),
      control2: CGPoint(x: rect.width * 1.12, y: rect.height * 0.72))
    path.closeSubpath()
    return path
  }
}

struct JourneyCrescent: View {
  var accent: String = "brown"

  var body: some View {
    Image("JourneyCrescent")
      .resizable()
      .scaledToFit()
      .accessibilityHidden(true)
      .allowsHitTesting(false)
  }
}

struct PointsCurrencyIcon: View {
  var body: some View {
    Image("MosaicCurrency")
      .resizable()
      .scaledToFit()
      .accessibilityHidden(true)
  }
}
