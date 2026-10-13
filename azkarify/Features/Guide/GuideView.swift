import SwiftUI
import UIKit

/// The full-screen "How to pray" guide: the character on the stage behind, a
/// speech bubble with the words for the current step, and Back / Next below.
struct GuideView: View {
  let onClose: () -> Void

  @EnvironmentObject private var store: AzkarStore
  @AppStorage("accent") private var accent = "brown"
  @AppStorage("guideKidsMode") private var kidsMode = true
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var steps: [GuideStep] = []
  @State private var index = 0
  @State private var transitionID = 0
  @State private var showSheet = false
  @State private var loadError: String?
  @State private var stageFrame: CGRect = .zero
  @State private var slotTop: CGFloat = 0
  @State private var bubbleFrame: CGRect = .zero

  private var step: GuideStep? { steps.indices.contains(index) ? steps[index] : nil }
  private var isLastStep: Bool { index >= steps.count - 1 }
  private var tint: Color { AppAppearance.accent(accent) }

  var body: some View {
    ZStack {
      AppAppearance.background(accent).ignoresSafeArea()
      if let step {
        GuideStage(
          posture: step.posture, enterClips: step.enterClips, transitionID: transitionID,
          accent: accent
        )
        .environment(\.layoutDirection, .leftToRight)
        .ignoresSafeArea()
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { stageFrame = $0 }
      }
      VStack(spacing: 0) {
        topBar
        if let step {
          progress
          bubbleSlot(step)
          Spacer(minLength: 0)
          bottomBar
        } else if let loadError {
          Spacer()
          ContentUnavailableView(
            text("Could not load the guide", "تعذر تحميل الدليل"), systemImage: "exclamationmark.triangle",
            description: Text(loadError))
          Spacer()
        } else {
          Spacer()
          ProgressView()
          Spacer()
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 8)
    }
    .task { reload(keepingSection: nil) }
    .onChange(of: kidsMode) { reload(keepingSection: step?.section) }
    .sensoryFeedback(.impact(weight: .light), trigger: index)
    .sheet(isPresented: $showSheet) {
      if let step {
        GuideStepSheet(step: step, language: store.language, accent: accent)
          .presentationDetents([.medium, .large])
          .presentationDragIndicator(.visible)
      }
    }
    .tint(tint)
    .environment(\.layoutDirection, store.language == "ar" ? .rightToLeft : .leftToRight)
  }

  // MARK: Top

  private var topBar: some View {
    HStack(spacing: 8) {
      Button(action: onClose) {
        Image(systemName: "xmark")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.primary)
          .frame(width: 44, height: 44)
          .background(.regularMaterial, in: Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(text("Close", "إغلاق"))
      .accessibilityIdentifier("guide.close")

      Text(step?.section.title.value(language: store.language) ?? "")
        .font(AppAppearance.font(size: 17, relativeTo: .headline, bold: true))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 14)
        .frame(minHeight: 36)
        .background(.regularMaterial, in: Capsule())
        .opacity(step == nil ? 0 : 1)
        .frame(maxWidth: .infinity)
        .accessibilityAddTraits(.isHeader)

      modeSwitch
    }
    .padding(.top, 4)
  }

  private var modeSwitch: some View {
    HStack(spacing: 2) {
      modeSegment(text("Kids", "للصغار"), selected: kidsMode)
      modeSegment(text("Full", "كاملة"), selected: !kidsMode)
    }
    .padding(3)
    .background(.regularMaterial, in: Capsule())
    .frame(minHeight: 44)
    .contentShape(Rectangle())
    .onTapGesture { kidsMode.toggle() }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(text("Guide length", "طول الدليل"))
    .accessibilityValue(kidsMode ? "kids" : "full")
    .accessibilityHint(text("Switches between the short and the full prayer", "يبدّل بين الصلاة المختصرة والكاملة"))
    .accessibilityAddTraits(.isButton)
    .accessibilityAction { kidsMode.toggle() }
    .accessibilityIdentifier("guide.mode")
  }

  private func modeSegment(_ title: String, selected: Bool) -> some View {
    Text(title)
      .font(AppAppearance.font(size: 13, relativeTo: .footnote, bold: true))
      .lineLimit(1)
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
      .foregroundStyle(selected ? Color(uiColor: .systemBackground) : Color.primary)
      .background(selected ? tint : Color.clear, in: Capsule())
  }

  private var progress: some View {
    HStack(spacing: 10) {
      ProgressView(value: Double(index + 1), total: Double(max(steps.count, 1)))
        .progressViewStyle(.linear)
        .tint(tint)
        .accessibilityHidden(true)
      Text(text("\(index + 1) of \(steps.count)", "\(index + 1) من \(steps.count)"))
        .font(AppAppearance.font(size: 13, relativeTo: .caption, bold: true))
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .fixedSize()
        .accessibilityIdentifier("guide.progress")
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 6)
    .background(.regularMaterial, in: Capsule())
    .padding(.top, 8)
  }

  // MARK: Bubble

  private static let tailSize: CGFloat = 12
  private static let maxBubbleWidth: CGFloat = 520

  private var isRightToLeft: Bool { store.language == "ar" }

  /// Converts a point in the stage's 9:16 scene (fractions) into global points.
  /// The stage fills its frame, so the scene is cropped on the long side.
  private func scenePoint(x: CGFloat, y: CGFloat) -> CGPoint {
    guard stageFrame.width > 0, stageFrame.height > 0 else { return .zero }
    let aspect: CGFloat = 9.0 / 16.0
    let sceneSize =
      stageFrame.width / stageFrame.height < aspect
      ? CGSize(width: stageFrame.height * aspect, height: stageFrame.height)
      : CGSize(width: stageFrame.width, height: stageFrame.width / aspect)
    let cropX = (sceneSize.width - stageFrame.width) / 2
    let cropY = (sceneSize.height - stageFrame.height) / 2
    return CGPoint(
      x: stageFrame.minX + sceneSize.width * x - cropX,
      y: stageFrame.minY + sceneSize.height * y - cropY)
  }

  /// The room the bubble may use for `step`, in global points: a full-width
  /// card above the character's head, or a narrower card on the empty wall
  /// beside it that points at the face.
  private func bubbleRoom(for step: GuideStep) -> BubbleRoom {
    let metrics = GuideCharacterMetrics.metrics(for: step.posture)
    let head = scenePoint(x: metrics.headMinX, y: metrics.headTop)
    let face = scenePoint(x: metrics.faceX, y: metrics.faceY)
    let wallBottom = scenePoint(x: 0, y: GuideCharacterMetrics.wallBottom).y
    let fullWidth = min(max(stageFrame.width - 32, 0), Self.maxBubbleWidth)
    guard stageFrame.width > 0, slotTop > 0 else {
      return BubbleRoom(fullWidth: fullWidth, fullHeight: 220, sideWidth: 0, sideHeight: 0, face: .zero)
    }
    // Leave room for the bottom bar whatever the illustration says.
    let limit = max(stageFrame.maxY - slotTop - 150, 120)
    let fullHeight = min(max(head.y - slotTop - 6, 120), limit)
    let sideWidth = min(head.x - stageFrame.minX - 16 - 8, Self.maxBubbleWidth)
    let sideHeight = min(wallBottom - slotTop, limit)
    let sideFits = sideWidth >= 170 && sideHeight > fullHeight
    return BubbleRoom(
      fullWidth: fullWidth, fullHeight: fullHeight, sideWidth: sideFits ? sideWidth : 0,
      sideHeight: sideFits ? sideHeight : 0, face: face)
  }

  private func bubbleSlot(_ step: GuideStep) -> some View {
    let room = bubbleRoom(for: step)
    return ZStack(alignment: .topLeading) {
      bubble(step, room: room)
        .id(step.id)
        .transition(.opacity)
    }
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: step.id)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .frame(height: max(room.fullHeight, room.sideHeight), alignment: .top)
    .environment(\.layoutDirection, .leftToRight)
    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { slotTop = $0 }
    .padding(.top, 12)
  }

  /// Picks the richest bubble that fits. Full-width candidates carry extra
  /// clear space so that they are measured against the room above the head,
  /// while side candidates are measured against the taller wall beside it.
  private func bubble(_ step: GuideStep, room: BubbleRoom) -> some View {
    let extra = max(room.sideHeight - room.fullHeight, 0)
    let hasSide = room.sideWidth > 0
    return ViewThatFits(in: .vertical) {
      bubbleCard(step, detail: .full, tail: .bottom, room: room).padding(.bottom, extra)
      bubbleCard(step, detail: .noTransliteration, tail: .bottom, room: room).padding(.bottom, extra)
      if hasSide { bubbleCard(step, detail: .full, tail: .side, room: room) }
      if hasSide { bubbleCard(step, detail: .noTransliteration, tail: .side, room: room) }
      bubbleCard(step, detail: .arabicOnly, tail: .bottom, room: room).padding(.bottom, extra)
      if hasSide { bubbleCard(step, detail: .arabicOnly, tail: .side, room: room) }
      bubbleCard(step, detail: .compact, tail: .bottom, room: room)
    }
  }

  private func bubbleCard(
    _ step: GuideStep, detail: BubbleDetail, tail: GuideBubbleShape.Edge, room: BubbleRoom
  ) -> some View {
    let shape = GuideBubbleShape(edge: tail, tailOffset: tailOffset(tail, face: room.face))
    let width = tail == .side ? room.sideWidth : room.fullWidth
    return bubbleContent(step, detail: detail, narrow: tail == .side)
      .padding(.bottom, tail == .bottom ? Self.tailSize : 0)
      .padding(.trailing, tail == .side ? Self.tailSize : 0)
      .frame(width: width)
      .background {
        shape
          .fill(.regularMaterial)
          .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
      }
      .contentShape(shape)
      .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { bubbleFrame = $0 }
      .onTapGesture { showSheet = true }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(bubbleLabel(step))
      .accessibilityValue(step.id)
      .accessibilityHint(text("Shows the full text", "يعرض النص كاملاً"))
      .accessibilityAddTraits(.isButton)
      .accessibilityAction { showSheet = true }
      .accessibilityIdentifier("guide.bubble")
      .overlay(alignment: .topTrailing) {
        Button { showSheet = true } label: {
          Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
            .background(.thinMaterial, in: Circle())
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, tail == .side ? Self.tailSize : 0)
        .accessibilityLabel(text("Show full text", "عرض النص كاملاً"))
        .accessibilityIdentifier("guide.expand")
      }
      .frame(maxWidth: .infinity, alignment: tail == .side ? .leading : .center)
  }

  /// Where the tail sits along its edge, in points from the card's left (bottom
  /// tail) or top (side tail), so that it points at the character's face.
  private func tailOffset(_ edge: GuideBubbleShape.Edge, face: CGPoint) -> CGFloat {
    guard bubbleFrame.width > 0, face != .zero else { return 60 }
    switch edge {
    case .bottom: return face.x - bubbleFrame.minX
    case .side: return face.y - bubbleFrame.minY
    }
  }

  private enum BubbleDetail {
    case full
    case noTransliteration
    case arabicOnly
    case compact
  }

  /// The bubble's text. A `narrow` bubble beside the head allows more lines
  /// because it has more height to use.
  private func bubbleContent(_ step: GuideStep, detail: BubbleDetail, narrow: Bool) -> some View {
    let instruction = step.instruction.value(language: store.language)
    return VStack(spacing: 8) {
      if step.arabic.isEmpty {
        Text(instruction)
          .font(AppAppearance.font(size: 18, relativeTo: .title3, bold: true))
          .lineLimit(detail == .compact ? 3 : nil)
          .padding(.horizontal, 20)
      } else {
        Text(instruction)
          .font(AppAppearance.font(size: 15, relativeTo: .subheadline))
          .foregroundStyle(.secondary)
          .lineLimit(detail == .compact ? 1 : narrow ? 3 : 2)
          .padding(.horizontal, 18)
        Text(step.arabic)
          .font(AppAppearance.font(size: 20, relativeTo: .title3, bold: true))
          .lineLimit(detail == .compact ? 2 : narrow ? 4 : 3)
          .multilineTextAlignment(.center)
          .environment(\.layoutDirection, .rightToLeft)
        if detail == .full, !step.transliteration.isEmpty {
          Text(step.transliteration)
            .font(AppAppearance.font(size: 14, relativeTo: .footnote))
            .italic()
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        if detail == .full || detail == .noTransliteration, !step.translated.isEmpty {
          Text(step.translated)
            .font(AppAppearance.font(size: 15, relativeTo: .subheadline))
            .lineLimit(narrow ? 3 : 2)
        }
        if step.repeatCount > 1 {
          Text(verbatim: "×\(step.repeatCount)")
            .font(AppAppearance.font(size: 13, relativeTo: .caption, bold: true))
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .foregroundStyle(tint)
            .background(tint.opacity(0.16), in: Capsule())
        }
      }
    }
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
    .padding(.horizontal, narrow ? 12 : 16)
    .padding(.vertical, step.arabic.isEmpty ? 18 : 14)
    .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
  }

  private func bubbleLabel(_ step: GuideStep) -> String {
    var parts = [step.instruction.value(language: store.language), step.arabic]
    parts.append(step.transliteration)
    parts.append(step.translated)
    if step.repeatCount > 1 {
      parts.append(text("Repeat \(step.repeatCount) times", "كرر \(step.repeatCount) مرات"))
    }
    return parts.filter { !$0.isEmpty }.joined(separator: "\n")
  }

  // MARK: Bottom

  private var bottomBar: some View {
    HStack(spacing: 12) {
      Button { go(to: index - 1) } label: {
        Label(text("Back", "السابق"), systemImage: "chevron.backward")
          .font(AppAppearance.font(size: 17, bold: true))
          .foregroundStyle(index == 0 ? Color.secondary : Color.primary)
          .padding(.horizontal, 20)
          .frame(minHeight: 50)
          .background(.regularMaterial, in: Capsule())
          .contentShape(Capsule())
      }
      .buttonStyle(.plain)
      .disabled(index == 0)
      .accessibilityIdentifier("guide.back")

      Button {
        if isLastStep { onClose() } else { go(to: index + 1) }
      } label: {
        HStack(spacing: 6) {
          Text(isLastStep ? text("Finish", "إنهاء") : text("Next", "التالي"))
          Image(systemName: isLastStep ? "checkmark" : "chevron.forward")
            .accessibilityHidden(true)
        }
        .font(AppAppearance.font(size: 17, bold: true))
        .foregroundStyle(Color(uiColor: .systemBackground))
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(tint, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .contentShape(Capsule())
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("guide.next")
    }
    .frame(maxWidth: Self.maxBubbleWidth)
  }

  // MARK: Actions

  private func go(to newIndex: Int) {
    guard steps.indices.contains(newIndex), newIndex != index else { return }
    index = newIndex
    transitionID += 1
  }

  private func reload(keepingSection section: GuideSection?) {
    do {
      let loaded = try GuideScript.steps(
        language: store.language, repository: store.repository, kids: kidsMode)
      loadError = nil
      steps = loaded
      let target = section.flatMap { section in loaded.firstIndex { $0.section == section } } ?? 0
      if target != index || section != nil {
        index = target
        transitionID += 1
      }
    } catch {
      loadError = error.localizedDescription
    }
  }

  private func text(_ english: String, _ arabic: String) -> String {
    JourneyText(english, arabic).value(language: store.language)
  }
}

/// Where the bubble may go, in points: `full*` for a card spanning the width
/// above the head, `side*` for a narrower card on the wall beside the head
/// (zero when there is no such room). `face` is in global points.
private struct BubbleRoom {
  let fullWidth: CGFloat
  let fullHeight: CGFloat
  let sideWidth: CGFloat
  let sideHeight: CGFloat
  let face: CGPoint
}

/// Where the character is drawn in each keyframe illustration, as fractions of
/// the 9:16 scene. The drawn fallback scene puts the character elsewhere, so it
/// gets its own conservative numbers.
struct GuideCharacterMetrics {
  /// Top of the head (or raised hands).
  let headTop: CGFloat
  /// Left edge of the head and hands above `wallBottom`.
  let headMinX: CGFloat
  let faceX: CGFloat
  let faceY: CGFloat

  /// The lowest point a bubble beside the head may reach.
  static let wallBottom: CGFloat = 0.60

  static func metrics(for posture: GuidePosture) -> GuideCharacterMetrics {
    guard GuideStage.hasKeyframe(posture) else {
      return GuideCharacterMetrics(headTop: 0.37, headMinX: 0.15, faceX: 0.36, faceY: 0.44)
    }
    switch posture {
    case .standing, .rising:
      return GuideCharacterMetrics(headTop: 0.285, headMinX: 0.53, faceX: 0.62, faceY: 0.36)
    case .takbir:
      return GuideCharacterMetrics(headTop: 0.285, headMinX: 0.51, faceX: 0.62, faceY: 0.36)
    case .bowing:
      return GuideCharacterMetrics(headTop: 0.375, headMinX: 0.16, faceX: 0.32, faceY: 0.47)
    case .prostrating:
      return GuideCharacterMetrics(headTop: 0.74, headMinX: 0.20, faceX: 0.30, faceY: 0.82)
    case .sitting, .tashahhud:
      return GuideCharacterMetrics(headTop: 0.37, headMinX: 0.48, faceX: 0.62, faceY: 0.44)
    case .salamRight, .salamLeft:
      return GuideCharacterMetrics(headTop: 0.42, headMinX: 0.53, faceX: 0.66, faceY: 0.50)
    case .after:
      return GuideCharacterMetrics(headTop: 0.43, headMinX: 0.47, faceX: 0.66, faceY: 0.51)
    }
  }
}

/// A rounded card with a small tail pointing at the character: down from the
/// bottom edge, or right from the right edge. `tailOffset` is the tail's
/// position along that edge, from the card's left or top.
struct GuideBubbleShape: Shape {
  enum Edge {
    case bottom
    case side
  }

  var edge: Edge
  var tailOffset: CGFloat
  var tailSize: CGFloat = 12

  func path(in rect: CGRect) -> Path {
    switch edge {
    case .bottom:
      let body = CGRect(
        x: rect.minX, y: rect.minY, width: rect.width, height: max(rect.height - tailSize, 0))
      let x = rect.minX + clamp(tailOffset, 34, rect.width - 34)
      var tail = Path()
      tail.move(to: CGPoint(x: x - 11, y: body.maxY - 2))
      tail.addQuadCurve(
        to: CGPoint(x: x + 1, y: rect.maxY), control: CGPoint(x: x - 2, y: body.maxY + 3))
      tail.addQuadCurve(
        to: CGPoint(x: x + 11, y: body.maxY - 2), control: CGPoint(x: x + 3, y: body.maxY + 2))
      tail.closeSubpath()
      return Path(roundedRect: body, cornerRadius: 22, style: .continuous).union(tail)
    case .side:
      let body = CGRect(
        x: rect.minX, y: rect.minY, width: max(rect.width - tailSize, 0), height: rect.height)
      let y = rect.minY + clamp(tailOffset, 34, rect.height - 34)
      var tail = Path()
      tail.move(to: CGPoint(x: body.maxX - 2, y: y - 11))
      tail.addQuadCurve(
        to: CGPoint(x: rect.maxX, y: y + 1), control: CGPoint(x: body.maxX + 3, y: y - 2))
      tail.addQuadCurve(
        to: CGPoint(x: body.maxX - 2, y: y + 11), control: CGPoint(x: body.maxX + 2, y: y + 3))
      tail.closeSubpath()
      return Path(roundedRect: body, cornerRadius: 22, style: .continuous).union(tail)
    }
  }

  private func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
    min(max(value, low), max(high, low))
  }
}

/// The full text of one guide step, shown in a sheet from the bubble.
struct GuideStepSheet: View {
  let step: GuideStep
  let language: String
  let accent: String

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text(step.section.title.value(language: language))
          .font(AppAppearance.font(size: 13, relativeTo: .footnote, bold: true))
          .foregroundStyle(AppAppearance.accent(accent))
          .textCase(.uppercase)
        Text(step.instruction.value(language: language))
          .font(AppAppearance.font(size: step.arabic.isEmpty ? 22 : 17, relativeTo: .headline, bold: true))
        if !step.arabic.isEmpty {
          Text(step.arabic)
            .font(AppAppearance.font(size: 24, relativeTo: .title2, bold: true))
            .lineSpacing(8)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)
            .textSelection(.enabled)
            .accessibilityIdentifier("guide.sheet.arabic")
        }
        if !step.transliteration.isEmpty {
          Text(step.transliteration)
            .font(AppAppearance.font(size: 16, relativeTo: .body))
            .italic()
            .foregroundStyle(.secondary)
        }
        if !step.translated.isEmpty {
          Text(step.translated)
            .font(AppAppearance.font(size: 17, relativeTo: .body))
        }
        repeatLine
        if let line = step.sourceLineID {
          Text(text("Hisn al-Muslim · entry \(line)", "حصن المسلم · الذكر \(line)"))
            .font(AppAppearance.font(size: 13, relativeTo: .footnote))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
      }
      .frame(maxWidth: 640, alignment: .leading)
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 20)
      .padding(.top, 28)
      .padding(.bottom, 24)
    }
    .accessibilityIdentifier("guide.sheet")
    .tint(AppAppearance.accent(accent))
    .environment(\.layoutDirection, language == "ar" ? .rightToLeft : .leftToRight)
  }

  private var repeatLine: some View {
    let count = step.repeatCount
    let sentence =
      count > 1
      ? text("Repeat \(count) times", "كرر \(count) مرات")
      : text("Say it once", "قلها مرة واحدة")
    return Label(sentence, systemImage: count > 1 ? "repeat" : "1.circle")
      .font(AppAppearance.font(size: 15, relativeTo: .subheadline, bold: count > 1))
      .foregroundStyle(count > 1 ? AppAppearance.accent(accent) : Color.secondary)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(String(count))
      .accessibilityValue(sentence)
      .accessibilityIdentifier("guide.sheet.repeat")
  }

  private func text(_ english: String, _ arabic: String) -> String {
    JourneyText(english, arabic).value(language: language)
  }
}
