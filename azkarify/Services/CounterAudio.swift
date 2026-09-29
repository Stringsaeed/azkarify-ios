import AVFAudio
import CoreHaptics
import OSLog

@MainActor
final class CounterAudio {
  enum Cue {
    case tick, reset, completion
  }

  private let logger = Logger(subsystem: "azkarify", category: "CounterAudio")
  private var engine: CHHapticEngine?
  private var player: (any CHHapticPatternPlayer)?

  func prepare() {
    guard CHHapticEngine.capabilitiesForHardware().supportsAudio else { return }
    do {
      if engine == nil {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, mode: .default)
        let engine = try CHHapticEngine(audioSession: session)
        engine.playsAudioOnly = true
        engine.isAutoShutdownEnabled = true
        engine.resetHandler = { [weak self] in
          Task { @MainActor in self?.player = nil }
        }
        self.engine = engine
      }
      try engine?.start()
    } catch {
      logger.debug("Counter audio unavailable: \(error.localizedDescription)")
    }
  }

  func play(_ cue: Cue) {
    prepare()
    guard let engine else { return }
    // A rapid tap replaces the previous cue instead of layering sounds.
    try? player?.stop(atTime: CHHapticTimeImmediate)
    player = nil
    do {
      player = try engine.makePlayer(with: Self.pattern(for: cue))
      try player?.start(atTime: CHHapticTimeImmediate)
    } catch {
      logger.debug("Counter cue skipped: \(error.localizedDescription)")
    }
  }

  func stop() {
    engine?.stop(completionHandler: nil)
    player = nil
  }

  private static func pattern(for cue: Cue) throws -> CHHapticPattern {
    let events: [CHHapticEvent]
    switch cue {
    case .tick:
      events = [tone(pitch: 0.3, brightness: 0.4, time: 0, duration: 0.045)]
    case .reset:
      events = [tone(pitch: -0.2, brightness: 0.15, time: 0, duration: 0.06)]
    case .completion:
      events = [
        tone(pitch: 0, brightness: 0.3, time: 0, duration: 0.09),
        tone(pitch: 0.35, brightness: 0.3, time: 0.09, duration: 0.13),
      ]
    }
    return try CHHapticPattern(events: events, parameters: [])
  }

  private static func tone(
    pitch: Float, brightness: Float, time: TimeInterval, duration: TimeInterval
  ) -> CHHapticEvent {
    CHHapticEvent(
      eventType: .audioContinuous,
      parameters: [
        CHHapticEventParameter(parameterID: .audioVolume, value: 0.15),
        CHHapticEventParameter(parameterID: .audioPitch, value: pitch),
        CHHapticEventParameter(parameterID: .audioBrightness, value: brightness),
        CHHapticEventParameter(parameterID: .attackTime, value: 0.005),
        CHHapticEventParameter(parameterID: .releaseTime, value: 0.02),
      ],
      relativeTime: time,
      duration: duration)
  }
}
