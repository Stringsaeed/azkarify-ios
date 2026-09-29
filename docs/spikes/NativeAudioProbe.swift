import AVFAudio
import CoreHaptics

// Standalone feasibility probe, intentionally outside the app target.
// Keep this object alive while auditioning. Call prepare() before interaction.
@MainActor
final class NativeAudioProbe {
    enum Cue: CaseIterable {
        case tap, select, success
    }

    private let engine: CHHapticEngine
    private var player: (any CHHapticPatternPlayer)?

    init?() throws {
        guard CHHapticEngine.capabilitiesForHardware().supportsAudio else {
            return nil
        }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, mode: .default)
        engine = try CHHapticEngine(audioSession: session)
        engine.playsAudioOnly = true
        engine.isAutoShutdownEnabled = true
        engine.resetHandler = { [weak self] in
            Task { @MainActor in
                self?.player = nil
            }
        }
    }

    func prepare() throws {
        try engine.start()
    }

    func play(_ cue: Cue) throws {
        try engine.start()
        try player?.stop(atTime: CHHapticTimeImmediate)
        player = try engine.makePlayer(with: Self.pattern(for: cue))
        try player?.start(atTime: CHHapticTimeImmediate)
    }

    static func pattern(for cue: Cue) throws -> CHHapticPattern {
        let events: [CHHapticEvent]
        switch cue {
        case .tap:
            events = [tone(pitch: 0.3, brightness: 0.4, time: 0, duration: 0.045)]
        case .select:
            events = [tone(pitch: -0.2, brightness: 0.15, time: 0, duration: 0.06)]
        case .success:
            events = [
                tone(pitch: 0, brightness: 0.3, time: 0, duration: 0.09),
                tone(pitch: 0.35, brightness: 0.3, time: 0.09, duration: 0.13)
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
                CHHapticEventParameter(parameterID: .releaseTime, value: 0.02)
            ],
            relativeTime: time,
            duration: duration
        )
    }
}
