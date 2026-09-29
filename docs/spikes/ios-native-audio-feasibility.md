# iOS native synthesized audio feasibility

Spike date: 2026-09-29

## Decision

Yes. A small Cuelume-like palette is feasible with Apple frameworks only, without bundling sound files. Use Core Haptics `CHHapticEventType.audioContinuous` for short synthesized cues and keep the palette deliberately small: tap, selection, and success are enough for a first pass.

Core Haptics is the quickest native fit because one `CHHapticPattern` can describe the cue, its duration, and its envelope. The separate `audioCustom` event is the file-backed option and is not needed here. Apple documents `audioContinuous` as an audio event with a looped waveform of arbitrary length, and Core Haptics exposes audio volume, pitch, pan, brightness, attack, decay, and release controls. Sources: [audioContinuous](https://developer.apple.com/documentation/corehaptics/chhapticevent/eventtype/audiocontinuous), [Core Haptics](https://developer.apple.com/documentation/CoreHaptics), [AHAP event parameters](https://developer.apple.com/documentation/corehaptics/representing-haptic-patterns-in-ahap-files).

That maps well to the reference project’s interaction model. Cuelume uses fourteen semantic cues, synthesizes them live with Web Audio, has no audio files, and exposes context such as direction, emphasis, and duration. Source: [cuelume README](https://github.com/danielwh2/cuelume).

## Native shape

The standalone probe at [`NativeAudioProbe.swift`](./NativeAudioProbe.swift) compiles against the iOS 27.1 simulator SDK. It creates an `AVAudioSession` with the `.ambient` category, constructs a `CHHapticEngine` from that session, enables audio-only playback, and defines three short `audioContinuous` patterns:

| Cue | Shape in the probe |
| --- | --- |
| `tap` | short, quiet bright tone |
| `select` | short, lower and darker tone |
| `success` | two tones spaced as a small ascending interval |

The probe guards on `CHHapticEngine.capabilitiesForHardware().supportsAudio`, keeps the engine alive, starts it immediately before playback, and recreates the player after an engine reset. These lifecycle details follow Apple’s [engine setup guidance](https://developer.apple.com/documentation/corehaptics/preparing-your-app-to-play-haptics) and [engine API](https://developer.apple.com/documentation/CoreHaptics/CHHapticEngine).

`supportsAudio` is a distinct capability from `supportsHaptics`; check the audio capability at runtime and make playback a no-op when it is unavailable. Apple exposes both through `CHHapticDeviceCapability`. Source: [CHHapticDeviceCapability](https://developer.apple.com/documentation/corehaptics/chhapticdevicecapability).

Using `.ambient` makes these cues secondary audio: they mix with other app audio and are silenced by the Ring/Silent switch and screen lock. That is likely the least surprising behavior for decorative interaction feedback. Source: [AVAudioSession.Category.ambient](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/ambient). Passing the shared session to `CHHapticEngine(audioSession:)` keeps Core Haptics aligned with the app’s audio behavior. Source: [CHHapticEngine.init(audioSession:)](https://developer.apple.com/documentation/corehaptics/chhapticengine/init%28audiosession%3A%29).

## Limits and tradeoffs

- Core Haptics gives a constrained synthesized palette, not arbitrary Web Audio DSP. `audioContinuous` exposes pitch, brightness, volume, pan, and envelopes; reproducing Cuelume’s richer mallet, room, noise, and theme system would need more synthesis control than this API offers.
- A capability check is required, and playback can stop on audio-session interruption, backgrounding, idle timeout, or engine failure. The app should treat cues as optional decoration and recover or silently skip them. Sources: [CHHapticEngine](https://developer.apple.com/documentation/CoreHaptics/CHHapticEngine), [preparing your app to play haptics](https://developer.apple.com/documentation/corehaptics/preparing-your-app-to-play-haptics).
- The `.ambient` choice respects user silence and other audio, but it also means cues will not play when the device is silent or locked. A different audio-session category would change that product behavior and could interrupt or compete with other audio. Source: [AVAudioSession](https://developer.apple.com/documentation/AVFAudio/AVAudioSession).
- This spike proves API availability and compile-time construction only. It does not yet prove perceived timbre, device-to-device loudness, latency, overlap behavior, or accessibility acceptance; those require listening on physical iPhones.

## Fallback if the palette needs more character

`AVAudioEngine` plus `AVAudioSourceNode` is also native and can generate sine, sawtooth, square, triangle, and noise waveforms from a real-time render callback. Apple’s signal-generator sample demonstrates that approach. It gives full control over harmonics and timing, but it adds an audio graph, PCM rendering, real-time safety rules, audio-session management, and more testing surface. Sources: [AVAudioSourceNode](https://developer.apple.com/documentation/avfaudio/avaudiosourcenode), [Building a signal generator](https://developer.apple.com/documentation/avfaudio/building-a-signal-generator), [AVAudioEngine](https://developer.apple.com/documentation/avfaudio/avaudioengine).

Do not start with that fallback for this feature. Prototype the three Core Haptics cues on a physical iPhone first; move to `AVAudioSourceNode` only if the constrained timbre cannot meet the desired product feel.
