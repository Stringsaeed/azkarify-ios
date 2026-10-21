import SwiftUI

/// The tasbih: one big round target. Counts up (free counter) or down from a repeat count.
struct CounterDial: View {
  let count: Int
  /// 0 counts up; otherwise the ring shows progress from this number down to zero.
  let startingCount: Int
  /// Count-up mode: progress (0...1) toward the next counter point.
  var pointProgress: Double = 0
  let onTap: () -> Void
  let onAdjust: (Int) -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var progress: Double {
    if startingCount > 0 { return Double(startingCount - count) / Double(startingCount) }
    return pointProgress
  }

  var body: some View {
    Button(action: onTap) {
      ZStack {
        Circle().fill(AZColor.peach).padding(-11)
        Circle().strokeBorder(AZColor.dialRing, lineWidth: AZBorder.hairline).padding(-11)
        Circle()
          .trim(from: 0, to: progress)
          .stroke(AZColor.spark, style: StrokeStyle(lineWidth: 4, lineCap: .round))
          .rotationEffect(.degrees(-90))
          .padding(-6)
          .animation(reduceMotion ? nil : AZMotion.curve(AZDuration.base), value: progress)
        Circle().fill(AZColor.blush)
        Circle().strokeBorder(AZColor.dialRim, lineWidth: AZBorder.hairline)
        Text(AZLocale.number(count))
          .azText(.numeral)
          .monospacedDigit()
          .foregroundStyle(AZColor.ink)
          .contentTransition(.numericText(value: Double(count)))
          .lineLimit(1)
          .minimumScaleFactor(0.5)
          .padding(.horizontal, 24)
        Image(systemName: startingCount > 0 ? "minus" : "plus")
          .font(.system(size: 24, weight: .medium))
          .foregroundStyle(AZColor.paper)
          .frame(width: 56, height: 56)
          .background(AZColor.ink, in: Circle())
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
          .offset(x: 4, y: 4)
          .accessibilityHidden(true)
      }
      .frame(width: 232, height: 232)
      .padding(11)
      .contentShape(Circle())
    }
    .buttonStyle(DialPressStyle())
    .environment(\.layoutDirection, .leftToRight)
    .accessibilityLabel(AZLocale.text("Count: \(count)", "العدد: \(AZLocale.number(count))"))
    .accessibilityHint(AZLocale.text("Double tap to change the count", "انقر مرتين لتغيير العدد"))
    .accessibilityIdentifier("counter.count")
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: onAdjust(1)
      case .decrement: onAdjust(-1)
      @unknown default: break
      }
    }
  }

  private struct DialPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
      configuration.label
        .scaleEffect(configuration.isPressed ? 0.98 : 1)
        .animation(AZMotion.curve(AZDuration.press), value: configuration.isPressed)
    }
  }
}

/// The counter, as the Counter tab (counts up) or a sheet for one zikr (counts down).
struct CounterView: View {
  @EnvironmentObject private var journeyProgress: JourneyProgressStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var initialCount = 0
  var title = ""
  /// The tab hosts the counter in its own navigation; the sheet draws its own close button.
  var isTab = false
  @State private var count = 0
  @State private var audio = CounterAudio()
  @State private var tapToken = 0
  @State private var didStart = false

  var body: some View {
    ScrollView {
      VStack(spacing: 28) {
        if !isTab { sheetHeader }
        if !title.isEmpty {
          Text(title)
            .azReadingArabic()
            .multilineTextAlignment(.center)
            .environment(\.layoutDirection, .rightToLeft)
            .frame(maxWidth: 560)
            .textSelection(.enabled)
            .accessibilityIdentifier("counter.title")
        }
        Text(instruction)
          .azText(.callout)
          .foregroundStyle(AZColor.inkMuted)
          .multilineTextAlignment(.center)
        CounterDial(
          count: count, startingCount: initialCount,
          pointProgress: Double(33 - journeyProgress.countsUntilNextPoint) / 33,
          onTap: { changeCount(by: initialCount > 0 ? -1 : 1) },
          onAdjust: { changeCount(by: $0) })
        VStack(spacing: 4) {
          Text(AZLocale.text(
            "\(journeyProgress.countsUntilNextPoint) to your next point",
            "\(AZLocale.number(journeyProgress.countsUntilNextPoint)) للنقطة التالية"))
            .azText(.headline)
            .monospacedDigit()
          Text(AZLocale.text("1 point for every 33 counts", "نقطة واحدة لكل ٣٣ تسبيحة"))
            .azText(.footnote)
            .foregroundStyle(AZColor.inkMuted)
        }
        .padding(.top, AZSpace.xs)
        Button(AZLocale.text("Reset", "إعادة")) { changeCount(to: initialCount, cue: .reset) }
          .buttonStyle(.azText)
          .disabled(count == initialCount)
      }
      .foregroundStyle(AZColor.ink)
      .padding(.horizontal, AZSpace.gutter)
      .padding(.top, isTab ? AZSpace.xl : AZSpace.lg)
      .padding(.bottom, AZSpace.xxl)
      .frame(maxWidth: .infinity)
    }
    .scrollBounceBehavior(.basedOnSize)
    .defaultScrollAnchor(.center, for: .alignment)
    .accessibilityIdentifier("counterZikrScroll")
    .azScreenBackground()
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .sensoryFeedback(.selection, trigger: tapToken)
    .sensoryFeedback(.success, trigger: count) { _, new in initialCount > 0 && new == 0 }
    .onAppear {
      if !didStart {
        count = initialCount
        didStart = true
      }
      audio.prepare()
    }
    .onDisappear { audio.stop() }
  }

  private var instruction: String {
    initialCount > 0
      ? AZLocale.text("Tap the circle to count down.", "انقر على الدائرة للعد التنازلي.")
      : AZLocale.text("Tap anywhere on the circle to count.", "انقر في أي مكان على الدائرة للعد.")
  }

  private var sheetHeader: some View {
    HStack {
      AZPointsBadge(points: journeyProgress.totalPoints)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AZLocale.text("Your points", "نقاطك"))
        .accessibilityValue(String(journeyProgress.totalPoints))
        .accessibilityIdentifier("counter.points")
      Spacer()
      Button { dismiss() } label: { Image(systemName: "xmark") }
        .buttonStyle(.azIcon(.filled))
        .accessibilityLabel(AZLocale.text("Close", "إغلاق"))
        .accessibilityIdentifier("counter.close")
    }
  }

  private func changeCount(by value: Int) {
    let next = max(0, count + value)
    let nextCount = initialCount > 0 ? min(initialCount, next) : next
    guard nextCount != count else { return }
    if initialCount > 0 ? value < 0 : value > 0 {
      journeyProgress.recordCounterTap()
      tapToken += 1
    }
    changeCount(to: nextCount, cue: initialCount > 0 && nextCount == 0 ? .completion : .tick)
  }

  private func changeCount(to value: Int, cue: CounterAudio.Cue) {
    guard value != count else { return }
    withAnimation(reduceMotion ? nil : AZMotion.curve(AZDuration.fast)) { count = value }
    audio.play(cue)
  }
}

/// The Counter tab: the free counter, full screen.
struct CounterTab: View {
  @EnvironmentObject private var journeyProgress: JourneyProgressStore

  var body: some View {
    NavigationStack {
      CounterView(isTab: true)
        .navigationTitle(AZLocale.text("Counter", "السبحة"))
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) { PointsToolbarButton() }
            .sharedBackgroundVisibility(.hidden)
        }
    }
  }
}
