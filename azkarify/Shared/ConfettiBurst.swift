import SwiftUI

struct ConfettiBurst: ViewModifier {
  @Binding var token: Int
  let accent: String
  let origin: CGPoint?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var startedAt: Date?

  private static let duration = 3.2
  private static let particles: [Particle] = (0..<220).map { (index: Int) -> Particle in
    let angle = Double((index * 73) % 221) / 220.0 * 2.0 - 1.0
    let delay = Double((index * 37) % 100) / 600.0
    let speed = 0.85 + Double((index * 43) % 100) / 150.0
    let rotation = Double((index * 61) % 360)
    let size = 5.0 + Double(index % 5)
    let rect = CGRect(x: -size / 2, y: -size / 3, width: size, height: size * 0.65)
    return Particle(angle: angle, delay: delay, speed: speed, dragOffset: exp(1.2 * delay),
                    rotation: rotation, color: index % 5,
                    shape: Path(roundedRect: rect, cornerRadius: 1))
  }

  func body(content: Content) -> some View {
    content
      .overlay {
        if let startedAt, !reduceMotion {
          GeometryReader { geometry in
            let frame = geometry.frame(in: .global)
            let launchPoint = origin.map {
              CGPoint(x: $0.x - frame.minX, y: $0.y - frame.minY)
            } ?? CGPoint(x: geometry.size.width / 2, y: geometry.size.height * 0.9)
            let colors = [
              AppAppearance.accent(accent), AppAppearance.accent("saffron"),
              AppAppearance.accent("teal"), AppAppearance.accent("green"), Color.white,
            ]
            let direction = atan2(geometry.size.height * 0.25 - launchPoint.y,
                                  geometry.size.width / 2 - launchPoint.x)
            let launchSpeed = hypot(geometry.size.width, geometry.size.height)
            let velocities = Self.particles.map { particle in
              let angle = direction + particle.angle * .pi / 3
              let speed = launchSpeed * particle.speed
              return CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
            }
            TimelineView(.animation) { timeline in
              Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(startedAt)
                let gravity = size.height * 1.4
                let drag = exp(-1.2 * elapsed)
                for index in Self.particles.indices {
                  let particle = Self.particles[index]
                  let velocity = velocities[index]
                  let time = elapsed - particle.delay
                  guard time >= 0 else { continue }
                  let horizontalTravel = (1 - drag * particle.dragOffset) / 1.2
                  let x = launchPoint.x + velocity.dx * horizontalTravel
                  let y = launchPoint.y + velocity.dy * time + 0.5 * gravity * time * time
                  guard x > -20, x < size.width + 20, y > -20, y < size.height + 20 else {
                    continue
                  }
                  var drawing = context
                  drawing.opacity = min(1, max(0, (Self.duration - time) / 0.7))
                  drawing.translateBy(x: x, y: y)
                  drawing.rotate(by: .degrees(particle.rotation + time * 180))
                  drawing.fill(particle.shape,
                               with: .color(colors[particle.color]))
                }
              }
            }
          }
          .ignoresSafeArea()
          .allowsHitTesting(false)
          .accessibilityHidden(true)
          .accessibilityIdentifier("completionConfetti")
        }
      }
      .sensoryFeedback(trigger: token) { oldValue, newValue in
        newValue > oldValue && !reduceMotion ? .success : nil
      }
      .task(id: token) {
        guard token > 0, !reduceMotion else {
          startedAt = nil
          return
        }
        startedAt = .now
        do {
          try await Task.sleep(for: .seconds(Self.duration + 0.2))
          startedAt = nil
        } catch {
          // A new celebration replaces this one.
        }
      }
  }

  private struct Particle {
    let angle: Double
    let delay: Double
    let speed: Double
    let dragOffset: Double
    let rotation: Double
    let color: Int
    let shape: Path
  }
}

extension View {
  func confettiBurst(token: Binding<Int>, accent: String, origin: CGPoint? = nil) -> some View {
    modifier(ConfettiBurst(token: token, accent: accent, origin: origin))
  }
}
