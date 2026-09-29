import Foundation

struct ZikrCategory: Codable, Identifiable, Hashable {
  let audioUrl: String
  let detailUrl: String
  let id: Int
  let title: String
}

struct ZikrIndex: Decodable { let items: [ZikrCategory] }

struct ZikrText: Decodable {
  let arabic: String
  let arabicTranslated: String
  let translated: String
}

struct ZikrEntry: Decodable, Identifiable {
  let audioUrl: String
  let id: Int
  let `repeat`: Int
  let text: ZikrText
}

struct ZikrDetails: Decodable { let items: [ZikrEntry] }
