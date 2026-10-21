/// SF Symbols for Hisn categories, replacing the old emoji. Mapped by category id.
enum CategorySymbol {
  static func forCategory(_ id: Int) -> String {
    switch id {
    case 1: "sunrise"
    case 2...5: "tshirt"
    case 6, 7: "door.left.hand.open"
    case 8, 9: "drop"
    case 10, 11: "house"
    case 12...14: "building.columns"
    case 15: "speaker.wave.2"
    case 16...26, 32, 33: "hands.and.sparkles"
    case 27: "sun.horizon"
    case 28...31, 67: "moon.stars"
    case 34...46: "cloud"
    case 47, 48: "figure.and.child.holdinghands"
    case 49...51: "cross.case"
    case 52...60: "leaf"
    case 61: "wind"
    case 62: "cloud.bolt"
    case 63...66: "cloud.rain"
    case 68: "sunset"
    case 69...76: "fork.knife"
    case 77, 78: "nose"
    case 79, 80: "heart"
    case 95...105: "suitcase"
    case 115...125: "cube"
    default: "hands.and.sparkles"
    }
  }
}
