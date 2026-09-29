enum ZikrEmoji {
  static func forCategory(_ id: Int) -> String {
    switch id {
    case 1: "☀️"
    case 2...5: "👕"
    case 6, 7: "🚻"
    case 8, 9: "💧"
    case 10, 11: "🏠"
    case 12...14: "🕌"
    case 15: "📣"
    case 16...25, 32, 33: "🤲"
    case 26: "🤲"
    case 27: "🌅"
    case 28...31: "🌙"
    case 34...46: "💭"
    case 47, 48: "👶"
    case 49...51: "🏥"
    case 52...60: "🕊️"
    case 61: "🌬️"
    case 62: "🌩️"
    case 63...66: "🌧️"
    case 67: "🌙"
    case 68: "🌇"
    case 69...76: "🍽️"
    case 77, 78: "🤧"
    case 79, 80: "💍"
    case 95...105: "🧳"
    case 115...125: "🕋"
    default: "🤲"
    }
  }
}
