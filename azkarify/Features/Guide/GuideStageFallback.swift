import SwiftUI

/// The drawn stage used while a posture has no keyframe illustration in the
/// asset catalog: the room with the character standing on the mat. It lays out
/// at 9:16 and fills whatever frame it is given.
struct GuideFallbackScene: View {
  let posture: GuidePosture
  var accent: String = "brown"

  var body: some View {
    ZStack {
      GuideRoom(accent: accent)
      GuideFigure(posture: posture)
    }
    .aspectRatio(9.0 / 16.0, contentMode: .fill)
    .accessibilityHidden(true)
  }
}

/// A quiet prayer room: plaster wall, an arched niche, a wooden floor, a mat and
/// a soft shaft of light. Drawn in 9:16 scene space.
struct GuideRoom: View {
  var accent: String = "brown"

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let dark = colorScheme == .dark
    let tint = AppAppearance.accent(accent)
    Canvas { context, size in
      let w = size.width
      let h = size.height
      let floorTop = h * GuideStageMetrics.floorTop

      // Wall.
      let wall = Path(CGRect(x: 0, y: 0, width: w, height: floorTop))
      context.fill(wall, with: .linearGradient(
        Gradient(colors: dark
          ? [rgb(0.18, 0.15, 0.13), rgb(0.13, 0.11, 0.09)]
          : [rgb(0.96, 0.92, 0.85), rgb(0.91, 0.85, 0.75)]),
        startPoint: .zero, endPoint: CGPoint(x: 0, y: floorTop)))
      context.fill(wall, with: .color(tint.opacity(dark ? 0.08 : 0.05)))

      // Niche.
      let nicheLeft = w * 0.60
      let nicheRight = w * 0.86
      let radius = (nicheRight - nicheLeft) / 2
      let nicheTop = h * 0.34
      let nicheBottom = h * 0.64
      var niche = Path()
      niche.move(to: CGPoint(x: nicheLeft, y: nicheBottom))
      niche.addLine(to: CGPoint(x: nicheLeft, y: nicheTop + radius))
      niche.addArc(
        center: CGPoint(x: nicheLeft + radius, y: nicheTop + radius), radius: radius,
        startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
      niche.addLine(to: CGPoint(x: nicheRight, y: nicheBottom))
      niche.closeSubpath()
      context.stroke(niche, with: .color(dark ? rgb(0.24, 0.20, 0.17) : rgb(0.99, 0.97, 0.93)),
                     lineWidth: w * 0.022)
      context.fill(niche, with: .linearGradient(
        Gradient(colors: dark
          ? [rgb(0.08, 0.07, 0.06), rgb(0.12, 0.10, 0.08)]
          : [rgb(0.80, 0.72, 0.59), rgb(0.87, 0.80, 0.68)]),
        startPoint: CGPoint(x: 0, y: nicheTop), endPoint: CGPoint(x: 0, y: nicheBottom)))
      var inner = context
      inner.clip(to: niche)
      inner.stroke(niche, with: .color(tint.opacity(0.35)), lineWidth: w * 0.012)
      let ledge = CGRect(x: nicheLeft - w * 0.02, y: nicheBottom, width: radius * 2 + w * 0.04,
                         height: h * 0.012)
      context.fill(Path(roundedRect: ledge, cornerRadius: 2),
                   with: .color(dark ? rgb(0.26, 0.22, 0.18) : rgb(0.84, 0.76, 0.64)))

      // Skirting and floor.
      context.fill(Path(CGRect(x: 0, y: floorTop - h * 0.012, width: w, height: h * 0.012)),
                   with: .color(dark ? rgb(0.22, 0.17, 0.13) : rgb(0.78, 0.68, 0.55)))
      let floor = Path(CGRect(x: 0, y: floorTop, width: w, height: h - floorTop))
      context.fill(floor, with: .linearGradient(
        Gradient(colors: dark
          ? [rgb(0.30, 0.21, 0.15), rgb(0.19, 0.13, 0.09)]
          : [rgb(0.75, 0.54, 0.35), rgb(0.57, 0.38, 0.24)]),
        startPoint: CGPoint(x: 0, y: floorTop), endPoint: CGPoint(x: 0, y: h)))
      var spacing = h * 0.016
      var lineY = floorTop + spacing
      var row = 0
      while lineY < h {
        var seam = Path()
        seam.move(to: CGPoint(x: 0, y: lineY))
        seam.addLine(to: CGPoint(x: w, y: lineY))
        let seamX = w * (row.isMultiple(of: 2) ? 0.27 : 0.71)
        seam.move(to: CGPoint(x: seamX, y: lineY))
        seam.addLine(to: CGPoint(x: seamX, y: lineY + spacing * 1.4))
        context.stroke(seam, with: .color(.black.opacity(dark ? 0.22 : 0.12)), lineWidth: 1)
        spacing *= 1.35
        lineY += spacing
        row += 1
      }

      // Mat.
      let matTop = h * 0.800
      let matBottom = h * 0.892
      var mat = Path()
      mat.move(to: CGPoint(x: w * 0.15, y: matTop))
      mat.addLine(to: CGPoint(x: w * 0.89, y: matTop))
      mat.addLine(to: CGPoint(x: w * 0.96, y: matBottom))
      mat.addLine(to: CGPoint(x: w * 0.08, y: matBottom))
      mat.closeSubpath()
      context.fill(mat.offsetBy(dx: 0, dy: h * 0.006), with: .color(.black.opacity(0.18)))
      context.fill(mat, with: .color(dark ? rgb(0.44, 0.38, 0.30) : rgb(0.92, 0.85, 0.71)))
      var border = Path()
      border.move(to: CGPoint(x: w * 0.175, y: matTop + h * 0.008))
      border.addLine(to: CGPoint(x: w * 0.865, y: matTop + h * 0.008))
      border.addLine(to: CGPoint(x: w * 0.925, y: matBottom - h * 0.008))
      border.addLine(to: CGPoint(x: w * 0.115, y: matBottom - h * 0.008))
      border.closeSubpath()
      context.stroke(border, with: .color(tint.opacity(dark ? 0.75 : 0.55)), lineWidth: w * 0.007)
      var motif = Path()
      let motifX = w * 0.83
      let motifBase = matBottom - h * 0.016
      motif.move(to: CGPoint(x: motifX - w * 0.035, y: motifBase))
      motif.addQuadCurve(
        to: CGPoint(x: motifX + w * 0.035, y: motifBase),
        control: CGPoint(x: motifX, y: matTop - h * 0.006))
      context.stroke(motif, with: .color(tint.opacity(dark ? 0.6 : 0.45)), lineWidth: w * 0.006)

      // Light shaft from a high window on the left.
      var shaft = Path()
      shaft.move(to: CGPoint(x: w * 0.02, y: 0))
      shaft.addLine(to: CGPoint(x: w * 0.34, y: 0))
      shaft.addLine(to: CGPoint(x: w * 0.82, y: matBottom))
      shaft.addLine(to: CGPoint(x: w * 0.36, y: matBottom))
      shaft.closeSubpath()
      context.fill(shaft, with: .linearGradient(
        Gradient(colors: [.white.opacity(dark ? 0.10 : 0.34), .white.opacity(0)]),
        startPoint: .zero, endPoint: CGPoint(x: w * 0.6, y: matBottom)))
      context.fill(
        Path(ellipseIn: CGRect(x: w * 0.36, y: matTop - h * 0.01, width: w * 0.46,
                               height: h * 0.07)),
        with: .radialGradient(
          Gradient(colors: [.white.opacity(dark ? 0.08 : 0.22), .white.opacity(0)]),
          center: CGPoint(x: w * 0.59, y: matTop + h * 0.025), startRadius: 0,
          endRadius: w * 0.24))

      // Vignette.
      context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
        Gradient(colors: [.clear, .black.opacity(dark ? 0.35 : 0.14)]),
        center: CGPoint(x: w * 0.5, y: h * 0.55), startRadius: h * 0.25, endRadius: h * 0.75))
    }
    .accessibilityHidden(true)
  }
}

/// A simple side view of the boy in the guide. Each posture is a set of joint
/// angles, so changing `posture` tweens the body from one position to the next.
struct GuideFigure: View {
  let posture: GuidePosture

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GuideFigureCanvas(pose: GuidePose(posture))
      .animation(reduceMotion ? nil : .easeInOut(duration: 0.9), value: posture)
      .accessibilityHidden(true)
  }
}

enum GuideStageMetrics {
  /// Where the wall meets the floor, as a fraction of the scene height.
  static let floorTop: CGFloat = 0.735
  /// Where the character's feet, knees and shins rest on the mat.
  static let groundLine: CGFloat = 0.846
  /// Horizontal position of the ankles, which stay in place on the mat.
  static let ankleAnchor: CGFloat = 0.34
  /// One body unit (a standing figure is about 6.9 units tall).
  static let unit: CGFloat = 0.064
}

/// Joint angles for the drawn character, in degrees. An angle of 0 points
/// straight down, 90 points forward (the way the character faces) and 180 points
/// up. `lean` tips the torso forward from upright and `head` nods the head on top
/// of that. `finger` raises the index finger and `turn` turns the head toward
/// (positive) or away from (negative) the viewer.
nonisolated struct GuidePose: VectorArithmetic {
  var thigh: Double
  var shin: Double
  var foot: Double
  var lean: Double
  var head: Double
  var upperArm: Double
  var forearm: Double
  var finger: Double
  var turn: Double

  init(
    thigh: Double, shin: Double, foot: Double, lean: Double, head: Double = 0,
    upperArm: Double, forearm: Double, finger: Double = 0, turn: Double = 0
  ) {
    self.thigh = thigh
    self.shin = shin
    self.foot = foot
    self.lean = lean
    self.head = head
    self.upperArm = upperArm
    self.forearm = forearm
    self.finger = finger
    self.turn = turn
  }

  init(_ posture: GuidePosture) {
    switch posture {
    case .standing:
      self.init(thigh: 0, shin: 0, foot: 90, lean: 0, upperArm: -5, forearm: 135)
    case .takbir:
      self.init(thigh: 0, shin: 0, foot: 90, lean: 0, upperArm: 75, forearm: 205)
    case .bowing:
      self.init(thigh: -4, shin: 4, foot: 90, lean: 88, upperArm: -43, forearm: -44)
    case .rising:
      self.init(thigh: 0, shin: 0, foot: 90, lean: 0, upperArm: 2, forearm: 6)
    case .prostrating:
      self.init(
        thigh: 20, shin: -108, foot: 20, lean: 118, head: 8, upperArm: -43, forearm: 83)
    case .sitting:
      self.init(thigh: 82, shin: -92, foot: -90, lean: 0, upperArm: 12, forearm: 80)
    case .tashahhud:
      self.init(thigh: 82, shin: -92, foot: -90, lean: 0, upperArm: 12, forearm: 72, finger: 1)
    case .salamRight:
      self.init(thigh: 82, shin: -92, foot: -90, lean: 0, upperArm: 12, forearm: 80, turn: 1)
    case .salamLeft:
      self.init(thigh: 82, shin: -92, foot: -90, lean: 0, upperArm: 12, forearm: 80, turn: -1)
    case .after:
      self.init(thigh: 82, shin: -92, foot: -90, lean: 0, head: 14, upperArm: 34, forearm: 165)
    }
  }

  private init(values v: [Double]) {
    self.init(
      thigh: v[0], shin: v[1], foot: v[2], lean: v[3], head: v[4], upperArm: v[5],
      forearm: v[6], finger: v[7], turn: v[8])
  }

  private var values: [Double] {
    [thigh, shin, foot, lean, head, upperArm, forearm, finger, turn]
  }

  static var zero: GuidePose { GuidePose(values: Array(repeating: 0, count: 9)) }

  static func + (lhs: GuidePose, rhs: GuidePose) -> GuidePose {
    GuidePose(values: zip(lhs.values, rhs.values).map(+))
  }

  static func - (lhs: GuidePose, rhs: GuidePose) -> GuidePose {
    GuidePose(values: zip(lhs.values, rhs.values).map(-))
  }

  mutating func scale(by rhs: Double) {
    self = GuidePose(values: values.map { $0 * rhs })
  }

  var magnitudeSquared: Double { values.reduce(0) { $0 + $1 * $1 } }
}

private struct GuideFigureCanvas: View, Animatable {
  var pose: GuidePose

  nonisolated var animatableData: GuidePose {
    get { pose }
    set { pose = newValue }
  }

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let pose = pose
    let dark = colorScheme == .dark
    Canvas { context, size in
      GuideFigureDrawing(pose: pose, size: size, dark: dark).draw(in: &context)
    }
  }
}

private struct GuideFigureDrawing {
  let pose: GuidePose
  let size: CGSize
  let dark: Bool

  // Segment lengths in body units.
  private let thighLength = 1.8
  private let shinLength = 1.7
  private let footLength = 0.72
  private let torsoLength = 2.0
  private let shoulderDrop = 0.28
  private let upperArmLength = 1.2
  private let forearmLength = 1.1
  private let headRadius = 0.62

  func draw(in context: inout GraphicsContext) {
    let unit = size.height * GuideStageMetrics.unit

    // Skeleton relative to the hip, in body units.
    let knee = step(.zero, pose.thigh, thighLength)
    let ankle = step(knee, pose.shin, shinLength)
    let toe = step(ankle, pose.foot, footLength)
    let neck = step(.zero, 180 - pose.lean, torsoLength)
    let shoulder = step(.zero, 180 - pose.lean, torsoLength - shoulderDrop)
    let headCenter = step(neck, 180 - pose.lean - pose.head, 0.15 + headRadius)
    let elbow = step(shoulder, pose.upperArm, upperArmLength)
    let hand = step(elbow, pose.forearm, forearmLength)

    // Rest the lowest of knee, ankle and toe on the mat, ankles at the anchor.
    let bottom = max(knee.y + 0.32, ankle.y + 0.2, toe.y + 0.16)
    let origin = CGPoint(
      x: size.width * GuideStageMetrics.ankleAnchor - ankle.x * unit,
      y: size.height * GuideStageMetrics.groundLine - bottom * unit)
    func place(_ point: CGPoint) -> CGPoint {
      CGPoint(x: origin.x + point.x * unit, y: origin.y + point.y * unit)
    }

    let skin = dark ? rgb(0.78, 0.60, 0.46) : rgb(0.88, 0.69, 0.53)
    let skinShade = dark ? rgb(0.66, 0.49, 0.36) : rgb(0.79, 0.58, 0.42)
    let thobe = dark ? rgb(0.80, 0.75, 0.66) : rgb(0.94, 0.89, 0.79)
    let thobeShade = dark ? rgb(0.70, 0.65, 0.56) : rgb(0.86, 0.80, 0.68)
    let kufi = dark ? rgb(0.92, 0.91, 0.88) : rgb(0.995, 0.99, 0.97)
    let outline = rgb(0.36, 0.26, 0.17).opacity(dark ? 0.8 : 0.6)
    let line = unit * 0.06

    func capsule(_ from: CGPoint, _ to: CGPoint, width: Double, fill: Color) {
      var path = Path()
      path.move(to: place(from))
      path.addLine(to: place(to))
      context.stroke(path, with: .color(outline),
                     style: StrokeStyle(lineWidth: width * unit + line * 2, lineCap: .round))
      context.stroke(path, with: .color(fill),
                     style: StrokeStyle(lineWidth: width * unit, lineCap: .round))
    }

    func disc(_ center: CGPoint, radius: Double, fill: Color) {
      let c = place(center)
      let r = radius * unit
      context.fill(Path(ellipseIn: CGRect(x: c.x - r - line, y: c.y - r - line,
                                          width: (r + line) * 2, height: (r + line) * 2)),
                   with: .color(outline))
      context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                   with: .color(fill))
    }

    // Soft contact shadow under the whole body.
    let xs = [knee.x, ankle.x, toe.x, headCenter.x, hand.x, 0].map { origin.x + $0 * unit }
    let groundY = size.height * GuideStageMetrics.groundLine
    let shadowRect = CGRect(
      x: (xs.min() ?? 0) - unit * 0.4, y: groundY - unit * 0.14,
      width: (xs.max() ?? 0) - (xs.min() ?? 0) + unit * 0.8, height: unit * 0.32)
    context.fill(Path(ellipseIn: shadowRect), with: .radialGradient(
      Gradient(colors: [.black.opacity(0.22), .black.opacity(0)]),
      center: CGPoint(x: shadowRect.midX, y: shadowRect.midY), startRadius: 0,
      endRadius: shadowRect.width / 2))

    // Legs under the thobe, feet bare.
    capsule(ankle, toe, width: 0.3, fill: skinShade)
    capsule(knee, ankle, width: 0.74, fill: thobeShade)
    capsule(.zero, knee, width: 0.86, fill: thobeShade)

    // Torso.
    capsule(.zero, neck, width: 1.1, fill: thobe)

    // Neck and head.
    capsule(neck, headCenter, width: 0.34, fill: skinShade)
    drawHead(in: &context, center: place(headCenter), unit: unit, skin: skin,
             skinShade: skinShade, kufi: kufi, outline: outline, line: line)

    // Near arm.
    capsule(shoulder, elbow, width: 0.42, fill: thobe)
    let wrist = step(elbow, pose.forearm, forearmLength - 0.12)
    capsule(elbow, wrist, width: 0.38, fill: thobe)
    if pose.finger > 0.01 {
      let tip = step(hand, pose.forearm + 62, 0.6 * pose.finger)
      capsule(hand, tip, width: 0.13, fill: skin)
    }
    disc(hand, radius: 0.21, fill: skin)
  }

  private func drawHead(
    in context: inout GraphicsContext, center: CGPoint, unit: CGFloat, skin: Color,
    skinShade: Color, kufi: Color, outline: Color, line: CGFloat
  ) {
    var head = context
    head.translateBy(x: center.x, y: center.y)
    head.rotate(by: .degrees(pose.lean + pose.head))
    let r = headRadius * unit
    let toward = max(pose.turn, 0)
    let away = max(-pose.turn, 0)

    func circle(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat) -> Path {
      Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
    }

    head.fill(circle(r * (0.92 - 0.95 * toward - 0.4 * away), r * 0.1, r * 0.17),
              with: .color(outline.opacity(1 - away)))
    head.fill(circle(0, 0, r + line), with: .color(outline))
    head.fill(circle(0, 0, r), with: .color(skin))
    head.fill(circle(r * (0.92 - 0.95 * toward - 0.4 * away), r * 0.1, r * 0.14),
              with: .color(skin.opacity(1 - away)))

    // Ear slides back as the face turns toward the viewer, forward as it turns away.
    head.fill(circle(r * (-0.12 + 0.38 * away - 0.5 * toward), r * 0.08, r * 0.17),
              with: .color(skinShade.opacity(1 - 0.8 * toward)))

    let eye = dark ? rgb(0.12, 0.09, 0.07) : rgb(0.22, 0.16, 0.12)
    head.fill(circle(r * (0.48 - 0.24 * toward), -r * 0.08, r * 0.085),
              with: .color(eye.opacity(1 - away)))
    head.fill(circle(r * (0.48 - 0.78 * toward), -r * 0.08, r * 0.085),
              with: .color(eye.opacity(toward)))
    var mouth = Path()
    let mouthX = r * (0.52 - 0.55 * toward)
    mouth.move(to: CGPoint(x: mouthX - r * 0.12, y: r * 0.36))
    mouth.addQuadCurve(to: CGPoint(x: mouthX + r * 0.1, y: r * 0.34),
                       control: CGPoint(x: mouthX, y: r * 0.44))
    head.stroke(mouth, with: .color(eye.opacity(0.7 * (1 - away))), lineWidth: max(1, r * 0.06))

    // White kufi over the crown.
    let cap = Path(ellipseIn: CGRect(x: -r * 1.06, y: -r * 1.1, width: r * 2.12, height: r * 2.12))
      .intersection(Path(CGRect(x: -r * 2, y: -r * 2, width: r * 4, height: r * 1.62)))
    head.stroke(cap, with: .color(outline), lineWidth: line * 2)
    head.fill(cap, with: .color(kufi))
    var band = Path()
    band.move(to: CGPoint(x: -r * 0.98, y: -r * 0.44))
    band.addLine(to: CGPoint(x: r * 0.98, y: -r * 0.44))
    head.stroke(band, with: .color(outline.opacity(0.5)), lineWidth: max(1, r * 0.05))
  }

  private func step(_ from: CGPoint, _ degrees: Double, _ length: Double) -> CGPoint {
    let radians = degrees * .pi / 180
    return CGPoint(x: from.x + sin(radians) * length, y: from.y + cos(radians) * length)
  }
}

private func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
  Color(red: red, green: green, blue: blue)
}
