import SwiftUI

enum Celebration {
  static func showsSlideshowProgress(entryCount: Int) -> Bool {
    entryCount > 3
  }
}

private struct CelebrateKey: EnvironmentKey {
  static let defaultValue: (CGPoint) -> Void = { _ in }
}

extension EnvironmentValues {
  var celebrate: (CGPoint) -> Void {
    get { self[CelebrateKey.self] }
    set { self[CelebrateKey.self] = newValue }
  }
}
