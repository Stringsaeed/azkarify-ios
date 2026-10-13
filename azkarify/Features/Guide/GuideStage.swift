import AVFoundation
import SwiftUI
import UIKit

/// The full-screen picture behind the guide: the character holding `posture`.
///
/// When `transitionID` changes and every clip in `enterClips` is bundled, the
/// clips play in order on top of the previous posture's keyframe, then the stage
/// crossfades to the new keyframe. Without clips, or with Reduce Motion on, it
/// crossfades between keyframes, or tweens the drawn character when the
/// keyframe illustrations are missing.
struct GuideStage: View {
  let posture: GuidePosture
  let enterClips: [GuideClip]
  let transitionID: Int
  var accent: String = "brown"

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @State private var shownPosture: GuidePosture
  @State private var settledPosture: GuidePosture
  @State private var playback = GuideClipPlayback()

  init(
    posture: GuidePosture, enterClips: [GuideClip], transitionID: Int, accent: String = "brown"
  ) {
    self.posture = posture
    self.enterClips = enterClips
    self.transitionID = transitionID
    self.accent = accent
    _shownPosture = State(initialValue: posture)
    _settledPosture = State(initialValue: posture)
  }

  var body: some View {
    Color.clear
      .overlay {
        ZStack {
          keyframeLayer
          if playback.isActive {
            let session = playback.session
            GuideClipPlayerView(player: playback.player) {
              playback.revealVideo(session: session)
            }
            .id(session)
            .opacity(playback.isVideoVisible ? 1 : 0)
          }
        }
      }
      .clipped()
      .allowsHitTesting(false)
      .accessibilityElement(children: .ignore)
      .accessibilityIdentifier("guide.stage")
      .accessibilityValue(posture.rawValue)
      .accessibilityAddTraits(.isImage)
      .onChange(of: enterClips, initial: true) { playback.prepare(enterClips) }
      .onChange(of: StageKey(posture: posture, transitionID: transitionID)) { old, new in
        advance(stepChanged: old.transitionID != new.transitionID)
      }
      .onChange(of: scenePhase) {
        if scenePhase == .active { playback.resume() }
      }
      .onDisappear { playback.cancel() }
  }

  @ViewBuilder private var keyframeLayer: some View {
    ZStack {
      if Self.hasKeyframe(shownPosture) {
        Image(shownPosture.keyframeName)
          .resizable()
          .scaledToFill()
          .id(shownPosture)
          .transition(.opacity)
      } else {
        GuideFallbackScene(posture: shownPosture, accent: accent)
          .transition(.opacity)
      }
    }
  }

  private func advance(stepChanged: Bool) {
    let previous = settledPosture
    settledPosture = posture
    playback.cancel()

    let clipsPlayable = !enterClips.isEmpty && enterClips.allSatisfy { $0.url != nil }
    if stepChanged, clipsPlayable, !reduceMotion {
      // The keyframe under the video holds the previous posture, which is also
      // the first frame of the first clip, until the video layer has a frame.
      withoutAnimation { shownPosture = previous }
      let target = posture
      let started = playback.play(enterClips) {
        withoutAnimation { shownPosture = target }
        playback.fadeOut(duration: 0.2)
      }
      if started { return }
    }
    withAnimation(.easeInOut(duration: 0.35)) { shownPosture = posture }
  }

  private func withoutAnimation(_ body: () -> Void) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction, body)
  }

  static func hasKeyframe(_ posture: GuidePosture) -> Bool {
    UIImage(named: posture.keyframeName) != nil
  }
}

private struct StageKey: Equatable {
  let posture: GuidePosture
  let transitionID: Int
}

/// Owns the single queue player that plays a transition's clips, and the state
/// the stage needs to show, reveal and remove the video layer.
@Observable
final class GuideClipPlayback {
  /// True while the video layer is in the hierarchy.
  private(set) var isActive = false
  /// True once the video layer has a frame to show, false while fading out.
  private(set) var isVideoVisible = false
  /// Bumped for every playback so stale callbacks are ignored and every
  /// playback gets a fresh player layer.
  private(set) var session = 0

  @ObservationIgnored private var queuePlayer: AVQueuePlayer?
  @ObservationIgnored private var preparedClips: [GuideClip] = []
  @ObservationIgnored private var preparedItems: [AVPlayerItem] = []
  @ObservationIgnored private var observers: [NSObjectProtocol] = []
  @ObservationIgnored private var watchdog: Task<Void, Never>?
  @ObservationIgnored private var onFinish: (() -> Void)?

  var player: AVQueuePlayer {
    if let queuePlayer { return queuePlayer }
    let player = AVQueuePlayer()
    player.isMuted = true
    player.preventsDisplaySleepDuringVideoPlayback = false
    player.actionAtItemEnd = .pause
    queuePlayer = player
    return player
  }

  /// Creates the items for `clips` ahead of time. While idle they are queued on
  /// the paused player so the first frame is decoded before the transition.
  func prepare(_ clips: [GuideClip]) {
    guard clips != preparedClips else { return }
    preparedClips = clips
    let urls = clips.compactMap(\.url)
    preparedItems = urls.count == clips.count ? urls.map { AVPlayerItem(url: $0) } : []
    guard !isActive, !preparedItems.isEmpty else { return }
    let player = player
    player.removeAllItems()
    for item in preparedItems { player.insert(item, after: nil) }
  }

  /// Plays `clips` in order and calls `onFinish` once the last one has ended
  /// on its final frame. Returns false when the clips cannot be played.
  func play(_ clips: [GuideClip], onFinish: @escaping () -> Void) -> Bool {
    cancel()
    prepare(clips)
    let items = preparedItems
    guard !items.isEmpty else { return false }
    preparedClips = []
    preparedItems = []

    let player = player
    if player.items() != items {
      player.removeAllItems()
      for item in items { player.insert(item, after: nil) }
    }
    // Advance through the queue, but hold the last item's final frame.
    player.actionAtItemEnd = items.count > 1 ? .advance : .pause

    session += 1
    let current = session
    self.onFinish = onFinish
    for (index, item) in items.enumerated() {
      let isLast = index == items.count - 1
      let isPenultimate = index == items.count - 2
      observers.append(NotificationCenter.default.addObserver(
        forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          guard let self, self.session == current else { return }
          if isPenultimate { self.queuePlayer?.actionAtItemEnd = .pause }
          if isLast { self.finish() }
        }
      })
      observers.append(NotificationCenter.default.addObserver(
        forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: item, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          guard let self, self.session == current else { return }
          self.finish()
        }
      })
    }
    // A clip that never loads must not leave the stage stuck on the old pose.
    watchdog = Task { [weak self] in
      try? await Task.sleep(for: .seconds(Double(items.count) * 6 + 2))
      guard let self, !Task.isCancelled, self.session == current else { return }
      self.finish()
    }

    isVideoVisible = false
    isActive = true
    player.play()
    return true
  }

  func revealVideo(session: Int) {
    guard isActive, onFinish != nil, session == self.session else { return }
    isVideoVisible = true
  }

  /// Fades the video out over the keyframe beneath it, then removes it.
  func fadeOut(duration: Double) {
    let current = session
    withAnimation(.easeInOut(duration: duration)) {
      isVideoVisible = false
    } completion: { [weak self] in
      guard let self, self.session == current else { return }
      self.deactivate()
    }
  }

  func resume() {
    guard isActive, onFinish != nil else { return }
    queuePlayer?.play()
  }

  /// Stops any playback at once and removes the video layer.
  func cancel() {
    guard isActive || onFinish != nil else { return }
    session += 1
    stopObserving()
    onFinish = nil
    deactivate()
  }

  private func finish() {
    stopObserving()
    let handler = onFinish
    onFinish = nil
    handler?()
  }

  private func deactivate() {
    isActive = false
    isVideoVisible = false
    queuePlayer?.pause()
    queuePlayer?.removeAllItems()
    queuePlayer?.actionAtItemEnd = .pause
  }

  private func stopObserving() {
    watchdog?.cancel()
    watchdog = nil
    observers.forEach(NotificationCenter.default.removeObserver)
    observers.removeAll()
  }
}

/// Hosts an `AVPlayerLayer` that fills its bounds and reports when it has a
/// frame ready, so the stage can keep the keyframe visible until then.
struct GuideClipPlayerView: UIViewRepresentable {
  let player: AVPlayer
  let onReadyForDisplay: () -> Void

  func makeUIView(context: Context) -> GuidePlayerLayerView {
    let view = GuidePlayerLayerView()
    view.onReadyForDisplay = onReadyForDisplay
    view.playerLayer.player = player
    return view
  }

  func updateUIView(_ view: GuidePlayerLayerView, context: Context) {
    view.onReadyForDisplay = onReadyForDisplay
    if view.playerLayer.player !== player { view.playerLayer.player = player }
  }

  static func dismantleUIView(_ view: GuidePlayerLayerView, coordinator: ()) {
    view.onReadyForDisplay = nil
    view.playerLayer.player = nil
  }
}

final class GuidePlayerLayerView: UIView {
  override class var layerClass: AnyClass { AVPlayerLayer.self }

  var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
  var onReadyForDisplay: (() -> Void)?
  private var readyObservation: NSKeyValueObservation?

  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    backgroundColor = .clear
    playerLayer.videoGravity = .resizeAspectFill
    weak let weakSelf = self
    readyObservation = playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) {
      layer, _ in
      guard layer.isReadyForDisplay else { return }
      Task { @MainActor in weakSelf?.onReadyForDisplay?() }
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

#Preview("Standing") {
  GuideStage(posture: .standing, enterClips: [], transitionID: 0).ignoresSafeArea()
}

#Preview("Takbir") {
  GuideStage(posture: .takbir, enterClips: [], transitionID: 0).ignoresSafeArea()
}

#Preview("Bowing") {
  GuideStage(posture: .bowing, enterClips: [], transitionID: 0).ignoresSafeArea()
}

#Preview("Rising") {
  GuideStage(posture: .rising, enterClips: [], transitionID: 0).ignoresSafeArea()
}

#Preview("Prostrating") {
  GuideStage(posture: .prostrating, enterClips: [], transitionID: 0).ignoresSafeArea()
}

#Preview("Sitting") {
  GuideStage(posture: .sitting, enterClips: [], transitionID: 0).ignoresSafeArea()
}

#Preview("Tashahhud") {
  GuideStage(posture: .tashahhud, enterClips: [], transitionID: 0).ignoresSafeArea()
}

#Preview("Salam right") {
  GuideStage(posture: .salamRight, enterClips: [], transitionID: 0).ignoresSafeArea()
}

#Preview("Salam left") {
  GuideStage(posture: .salamLeft, enterClips: [], transitionID: 0).ignoresSafeArea()
}

#Preview("After") {
  GuideStage(posture: .after, enterClips: [], transitionID: 0, accent: "teal")
    .ignoresSafeArea()
}

#Preview("Cycle") {
  GuideStageCyclePreview()
}

private struct GuideStageCyclePreview: View {
  @State private var step = 0

  var body: some View {
    let postures = GuidePosture.allCases
    let posture = postures[step % postures.count]
    let previous = postures[(step + postures.count - 1) % postures.count]
    GuideStage(
      posture: posture,
      enterClips: step == 0 ? [] : [GuideClip(from: previous, to: posture)],
      transitionID: step)
      .ignoresSafeArea()
      .task {
        while !Task.isCancelled {
          try? await Task.sleep(for: .seconds(2.2))
          step += 1
        }
      }
  }
}
