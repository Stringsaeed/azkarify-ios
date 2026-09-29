import Foundation
import SwiftData

@Model
final class CachedAzkarDocument {
  @Attribute(.unique) var key: String
  var json: Data

  init(key: String, json: Data) {
    self.key = key
    self.json = json
  }
}
