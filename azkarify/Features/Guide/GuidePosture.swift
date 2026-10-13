import Foundation

/// The body positions the guide character can hold. Each has a keyframe asset
/// (`GuidePose-<rawValue>` in the asset catalog) that the stage shows while the
/// learner reads the lines for that position.
enum GuidePosture: String, CaseIterable, Hashable {
  case standing
  case takbir
  case bowing
  case rising
  case prostrating
  case sitting
  case tashahhud
  case salamRight
  case salamLeft
  case after

  var keyframeName: String { "GuidePose-\(rawValue)" }
}

/// A short bundled video that moves the character from one posture to the next.
/// The file is `guide-clip-<from>-to-<to>.mp4` in the app bundle. When the file
/// is missing the stage crossfades between the two keyframes instead.
struct GuideClip: Hashable {
  let from: GuidePosture
  let to: GuidePosture

  var resourceName: String { "guide-clip-\(from.rawValue)-to-\(to.rawValue)" }

  var url: URL? { Bundle.main.url(forResource: resourceName, withExtension: "mp4") }
}
