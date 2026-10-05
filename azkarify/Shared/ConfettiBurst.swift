import SwiftUI
import UIKit

struct ConfettiBurst: ViewModifier {
  @Binding var token: Int
  let accent: String
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var visibleToken = 0

  func body(content: Content) -> some View {
    content
      .overlay {
        if visibleToken > 0 && !reduceMotion {
          ConfettiEmitter(burstID: visibleToken, accentName: accent)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .accessibilityIdentifier("confettiBurst")
        }
      }
      .onChange(of: token) { _, newToken in
        guard newToken > 0, !reduceMotion else { return }
        visibleToken = newToken
        Task {
          try? await Task.sleep(for: .seconds(2.4))
          if visibleToken == newToken { visibleToken = 0 }
        }
      }
  }
}

extension View {
  func confettiBurst(token: Binding<Int>, accent: String) -> some View {
    modifier(ConfettiBurst(token: token, accent: accent))
  }
}

private struct ConfettiEmitter: UIViewRepresentable {
  var burstID: Int
  var accentName: String

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeUIView(context: Context) -> ConfettiCanvas {
    ConfettiCanvas()
  }

  func updateUIView(_ view: ConfettiCanvas, context: Context) {
    view.colors = ConfettiCanvas.palette(accentName)
    guard context.coordinator.lastBurstID != burstID else { return }
    context.coordinator.lastBurstID = burstID
    view.burst()
  }

  final class Coordinator {
    var lastBurstID = 0
  }
}

final class ConfettiCanvas: UIView {
  var colors: [UIColor] = []
  private var pendingBurst = false

  override class var layerClass: AnyClass { CAEmitterLayer.self }

  private var emitter: CAEmitterLayer { layer as! CAEmitterLayer }

  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    backgroundColor = .clear
    emitter.emitterShape = .line
    emitter.emitterMode = .outline
    emitter.birthRate = 0
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    emitter.emitterPosition = CGPoint(x: bounds.midX, y: -8)
    emitter.emitterSize = CGSize(width: max(bounds.width, 1), height: 1)
    if pendingBurst, bounds.width > 0 {
      pendingBurst = false
      startBurst()
    }
  }

  func burst() {
    pendingBurst = true
    if bounds.width > 0 {
      pendingBurst = false
      startBurst()
    } else {
      setNeedsLayout()
    }
  }

  private func startBurst() {
    emitter.beginTime = CACurrentMediaTime()
    emitter.emitterCells = colors.map(makeCell)
    emitter.birthRate = 1
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
      self?.emitter.birthRate = 0
    }
  }

  private func makeCell(color: UIColor) -> CAEmitterCell {
    let cell = CAEmitterCell()
    cell.birthRate = 14
    cell.lifetime = 2.8
    cell.lifetimeRange = 0.4
    cell.velocity = 220
    cell.velocityRange = 90
    cell.yAcceleration = 260
    cell.emissionLongitude = .pi
    cell.emissionRange = .pi / 6
    cell.spin = 3.2
    cell.spinRange = 4
    cell.scale = 0.45
    cell.scaleRange = 0.25
    cell.color = color.cgColor
    cell.contents = ConfettiCanvas.piece.cgImage
    return cell
  }

  static func palette(_ accentName: String) -> [UIColor] {
    let accent = UIColor(AppAppearance.accent(accentName))
    return [
      accent,
      UIColor(AppAppearance.accent("saffron")),
      UIColor(AppAppearance.accent("teal")),
      UIColor(AppAppearance.accent("green")),
      UIColor.white,
    ]
  }

  private static let piece: UIImage = {
    let size = CGSize(width: 10, height: 16)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
      UIColor.white.setFill()
      UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 2)
        .fill()
    }
  }()
}
