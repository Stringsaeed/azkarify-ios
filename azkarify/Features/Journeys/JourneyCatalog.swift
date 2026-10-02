import Foundation

struct JourneyText: Hashable {
  let english: String
  let arabic: String

  init(_ english: String, _ arabic: String) {
    self.english = english
    self.arabic = arabic
  }

  func value(language: String) -> String { language == "ar" ? arabic : english }
}

struct JourneyStepOption: Identifiable, Hashable {
  let id: String
  let title: JourneyText
}

struct JourneyStep: Identifiable, Hashable {
  let id: String
  let title: JourneyText
  let note: JourneyText?
  let categoryIDs: [Int]
  let isOptional: Bool
  let options: [JourneyStepOption]

  init(
    _ id: String, _ english: String, _ arabic: String, categories: [Int] = [],
    optional: Bool = false, note: JourneyText? = nil, options: [JourneyStepOption] = []
  ) {
    self.id = id
    title = JourneyText(english, arabic)
    self.note = note
    categoryIDs = categories
    isOptional = optional
    self.options = options
  }
}

struct JourneyDefinition: Identifiable, Hashable {
  let id: String
  let title: JourneyText
  let subtitle: JourneyText
  let symbol: String
  let prayer: DailyPrayer?
  let steps: [JourneyStep]

  var requiredSteps: [JourneyStep] { steps.filter { !$0.isOptional } }
}

/// Categories reference the existing bilingual Husn collection. This catalog contains
/// routine labels only; devotional text remains in the bundled source collection.
enum JourneyCatalog {
  static let morning = JourneyDefinition(
    id: "morning", title: .init("A gentle morning", "بداية صباحك"),
    subtitle: .init("Wake, prepare, and begin with remembrance", "استيقظ وتوضأ وابدأ يومك بالذكر"),
    symbol: "sunrise", prayer: nil,
    steps: [
      JourneyStep("wake", "Wake up", "الاستيقاظ", categories: [1]),
      JourneyStep("wudu", "Make wudu", "الوضوء", categories: [8, 9]),
      JourneyStep("morning-azkar", "Morning azkar", "أذكار الصباح", categories: [27]),
      JourneyStep(
        "prayer", "Pray Subh or Duha", "صلاة الصبح أو الضحى",
        note: .init("Choose the prayer for this routine.", "اختر الصلاة لهذه الرحلة."),
        options: [
          .init(id: "subh", title: .init("Subh", "الصبح")),
          .init(id: "duha", title: .init("Duha", "الضحى")),
        ])
    ])

  static let goingOut = JourneyDefinition(
    id: "going-out", title: .init("Heading out", "الخروج من المنزل"),
    subtitle: .init("A moment of remembrance before your day outside", "اذكر الله قبل أن تبدأ يومك خارج المنزل"),
    symbol: "door.left.hand.open", prayer: nil,
    steps: [
      JourneyStep("leave-home", "Leaving home azkar", "ذكر الخروج من المنزل", categories: [10]),
      JourneyStep(
        "ride", "Azkar when setting out", "ذكر الركوب عند الخروج", categories: [95], optional: true,
        note: .init("If you are riding in a vehicle.", "إذا كنت تركب وسيلة مواصلات."))
    ])

  static let evening = JourneyDefinition(
    id: "evening", title: .init("An evening pause", "وقفة المساء"),
    subtitle: .init("Make room for your evening azkar", "وقت هادئ لأذكار المساء"),
    symbol: "sunset", prayer: nil,
    steps: [JourneyStep("evening-azkar", "Evening azkar", "أذكار المساء", categories: [27])])

  static let sleep = JourneyDefinition(
    id: "sleep", title: .init("Rest with remembrance", "ختام يومك بالذكر"),
    subtitle: .init("Bedtime azkar, with a little help if you wake", "أذكار النوم وما يعينك إذا استيقظت ليلاً"),
    symbol: "moon.stars", prayer: nil,
    steps: [
      JourneyStep("sleep-azkar", "Bedtime azkar", "أذكار النوم", categories: [28]),
      JourneyStep(
        "night-waking", "If you wake during the night", "إذا استيقظت أثناء الليل", categories: [29],
        optional: true),
      JourneyStep("bad-dream", "After a troubling dream", "بعد حلم مزعج", categories: [31], optional: true)
    ])

  static let prayers: [JourneyDefinition] = DailyPrayer.allCases.map { prayer in
    JourneyDefinition(
      id: "prayer-\(prayer.rawValue)",
      title: .init("\(prayer.title(language: "en")) journey", "رحلة \(prayer.title(language: "ar"))"),
      subtitle: .init("Prepare, pray, and remember", "تهيأ للصلاة وأتمها بالذكر"),
      symbol: "sun.max", prayer: prayer,
      steps: [
        JourneyStep(
          "restroom", "Visit the restroom", "دخول الخلاء والخروج منه", categories: [6, 7],
          note: .init("If needed before wudu.", "عند الحاجة قبل الوضوء.")),
        JourneyStep("wudu", "Make wudu", "الوضوء", categories: [8, 9]),
        JourneyStep(
          "mosque", "Go to the mosque", "الذهاب إلى المسجد ودخوله", categories: [12, 13],
          note: .init("When praying at the mosque.", "عند الصلاة في المسجد.")),
        JourneyStep("adhan", "Azkar for the adhan", "أذكار الأذان", categories: [15]),
        JourneyStep(
          "before-iqama", "Dua before the iqama", "الدعاء بين الأذان والإقامة",
          note: .init("Take a moment for your own dua.", "خذ لحظة للدعاء بما تريد.")),
        JourneyStep(
          "prayer", "Pray with remembrance", "أذكار الصلاة", categories: [16, 17, 18, 19, 20, 21, 22, 23, 24]),
        JourneyStep("after-prayer", "After prayer azkar", "أذكار بعد الصلاة", categories: [25]),
        JourneyStep(
          "leave-mosque", "Leave the mosque", "الخروج من المسجد", categories: [14],
          note: .init("When praying at the mosque.", "عند الصلاة في المسجد."))
      ])
  }

  static let all = [morning, goingOut] + prayers + [evening, sleep]
}

/// Selects the next unfinished prayer journey from one day's already-calculated schedule.
///
/// The caller supplies today's schedule so the helper never reaches into tomorrow's prayers.
/// A journey ID uses the same canonical form as `JourneyCatalog.prayers`: `prayer-<name>`.
enum PrayerJourneyHighlight {
  static func nextJourneyID(
    on date: Date,
    prayers: [ScheduledPrayer],
    completedJourneyIDs: Set<String>
  ) -> String? {
    prayers
      .filter { $0.time > date }
      .sorted { $0.time < $1.time }
      .map { "prayer-\($0.prayer.rawValue)" }
      .first { !completedJourneyIDs.contains($0) }
  }
}
