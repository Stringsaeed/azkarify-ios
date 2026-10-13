import Foundation

enum GuideSection: Hashable {
  case firstRakah
  case secondRakah
  case closing
  case afterPrayer

  var title: JourneyText {
    switch self {
    case .firstRakah: JourneyText("First rak'ah", "الركعة الأولى")
    case .secondRakah: JourneyText("Second rak'ah", "الركعة الثانية")
    case .closing: JourneyText("Tashahhud and salam", "التشهد والتسليم")
    case .afterPrayer: JourneyText("After the prayer", "بعد الصلاة")
    }
  }
}

struct GuideStep: Identifiable, Hashable {
  let id: String
  let section: GuideSection
  let posture: GuidePosture
  let enterClips: [GuideClip]
  let instruction: JourneyText
  let arabic: String
  let translated: String
  let transliteration: String
  let repeatCount: Int
  let isEssential: Bool
  let sourceCategoryID: Int?
  let sourceLineID: Int?
}

extension GuideClip {
  static func path(from: GuidePosture, to: GuidePosture) -> [GuideClip] {
    switch (from, to) {
    case (.standing, .takbir), (.takbir, .standing), (.standing, .bowing), (.bowing, .rising),
      (.rising, .prostrating), (.prostrating, .sitting), (.sitting, .prostrating),
      (.sitting, .standing), (.prostrating, .tashahhud), (.tashahhud, .salamRight),
      (.salamRight, .salamLeft), (.salamLeft, .after):
      return [GuideClip(from: from, to: to)]
    case (.prostrating, .standing):
      return [
        GuideClip(from: .prostrating, to: .sitting),
        GuideClip(from: .sitting, to: .standing),
      ]
    default:
      preconditionFailure("No guide clip path from \(from) to \(to)")
    }
  }
}

enum GuideScript {
  private static let fatihaArabic =
    "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝ الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ ۝ الرَّحْمَٰنِ الرَّحِيمِ ۝ مَالِكِ يَوْمِ الدِّينِ ۝ إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ ۝ اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ ۝ صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ ۝ آمين"
  private static let fatihaEnglish =
    "In the name of Allah, the Most Gracious, the Most Merciful. All praise is for Allah, Lord of all the worlds. The Most Gracious, the Most Merciful. Master of the Day of Judgement. You alone we worship, and You alone we ask for help. Guide us to the straight path, the path of those You have blessed, not of those who earned Your anger, nor of those who went astray. Ameen."
  private static let ikhlasArabic =
    "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝ قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ"
  private static let ikhlasEnglish =
    "In the name of Allah, the Most Gracious, the Most Merciful. Say: He is Allah, the One. Allah, the Eternal Refuge. He neither begets nor is born, and there is none comparable to Him."
  private static let kawtharArabic =
    "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝ إِنَّا أَعْطَيْنَاكَ الْكَوْثَرَ ۝ فَصَلِّ لِرَبِّكَ وَانْحَرْ ۝ إِنَّ شَانِئَكَ هُوَ الْأَبْتَرُ"
  private static let kawtharEnglish =
    "In the name of Allah, the Most Gracious, the Most Merciful. Indeed, We have granted you Al-Kawthar. So pray to your Lord and sacrifice. Indeed, your enemy is the one cut off."

  @MainActor
  static func steps(language: String, repository: AzkarRepository, kids: Bool) throws -> [GuideStep] {
    let chapters = try GuideCatalog.load(language: language, repository: repository)
    let isEnglish = language != "ar"
    var raw: [GuideStep] = []
    var firstInstructions: [Int: JourneyText] = [:]

    func chapter(_ id: Int) throws -> GuideChapter {
      guard let found = chapters.first(where: { $0.categoryID == id }) else {
        throw CocoaError(.fileNoSuchFile)
      }
      return found
    }

    func line(_ category: Int, _ lineID: Int) throws -> GuideLine {
      guard let found = try chapter(category).lines.first(where: { $0.id == lineID }) else {
        throw CocoaError(.fileNoSuchFile)
      }
      return found
    }

    func add(
      _ id: String, _ section: GuideSection, _ posture: GuidePosture, _ instruction: JourneyText,
      arabic: String = "", english: String = "", transliteration: String = "", repeatCount: Int = 1,
      essential: Bool, category: Int? = nil, lineID: Int? = nil
    ) {
      raw.append(
        GuideStep(
          id: id, section: section, posture: posture, enterClips: [], instruction: instruction,
          arabic: arabic, translated: isEnglish ? english : "",
          transliteration: isEnglish ? transliteration : "", repeatCount: repeatCount,
          isEssential: essential, sourceCategoryID: category, sourceLineID: lineID))
    }

    func addLine(
      _ id: String, _ section: GuideSection, _ posture: GuidePosture, _ instruction: JourneyText,
      _ source: GuideLine, category: Int, essential: Bool
    ) {
      add(
        id, section, posture, instruction, arabic: source.arabic, english: source.translated,
        transliteration: source.transliteration, repeatCount: source.repeatCount,
        essential: essential, category: category, lineID: source.id)
    }

    func addLines(
      _ category: Int, prefix: String, _ section: GuideSection, _ posture: GuidePosture,
      first: JourneyText, rest: JourneyText? = nil,
      essential: (Int) -> Bool
    ) throws {
      let alternative = rest ?? JourneyText("Or say", "أو قل")
      firstInstructions[category] = first
      for (index, source) in try chapter(category).lines.enumerated() {
        addLine(
          "\(prefix)-\(category)-\(source.id)", section, posture,
          index == 0 ? first : alternative,
          source, category: category, essential: essential(source.id))
      }
    }

    let takbirArabic = "اللهُ أَكْبَرُ"
    let takbirEnglish = "Allah is the Greatest"
    let takbirLatin = "Allahu Akbar"
    let thenSay = JourneyText("Then say", "ثم قل")

    // First rak'ah
    add(
      "r1-stand", .firstRakah, .standing,
      JourneyText(
        "Stand facing the qiblah and make your intention in your heart",
        "قف مستقبلاً القبلة وانوِ الصلاة بقلبك"), essential: true)
    add(
      "r1-takbir", .firstRakah, .takbir,
      JourneyText("Raise your hands to your ears and say", "ارفع يديك إلى أذنيك وقل"),
      arabic: takbirArabic, english: takbirEnglish, transliteration: takbirLatin, essential: true)
    try addLines(
      16, prefix: "r1-opening", .firstRakah, .standing,
      first: JourneyText(
        "Place your right hand over your left on your chest and say",
        "ضع يدك اليمنى على اليسرى على صدرك وقل")
    ) { $0 == 28 }
    add(
      "r1-fatiha", .firstRakah, .standing, JourneyText("Recite Al-Fatiha", "اقرأ سورة الفاتحة"),
      arabic: fatihaArabic, english: fatihaEnglish, essential: true)
    add(
      "r1-surah", .firstRakah, .standing,
      JourneyText(
        "Then recite a short surah, for example Al-Ikhlas",
        "ثم اقرأ سورة قصيرة، مثل سورة الإخلاص"),
      arabic: ikhlasArabic, english: ikhlasEnglish, essential: true)
    try addLines(
      17, prefix: "r1-bow", .firstRakah, .bowing,
      first: JourneyText(
        "Say Allahu Akbar, bow with a straight back, hands on your knees, and say",
        "قل الله أكبر، واركع مستوياً ظهرك ويداك على ركبتيك، وقل")
    ) { $0 == 33 }
    try addLines(
      18, prefix: "r1-rise", .firstRakah, .rising,
      first: JourneyText("Rise up straight while saying", "ارفع من الركوع وأنت تقول")
    ) { $0 == 38 || $0 == 39 }
    try addLines(
      19, prefix: "r1-sujood", .firstRakah, .prostrating,
      first: JourneyText(
        "Say Allahu Akbar, prostrate with your forehead and nose on the ground, and say",
        "قل الله أكبر، واسجد على جبهتك وأنفك، وقل")
    ) { $0 == 41 }
    try addLines(
      20, prefix: "r1-sit", .firstRakah, .sitting,
      first: JourneyText("Say Allahu Akbar, sit up, and say", "قل الله أكبر، واجلس، وقل")
    ) { $0 == 48 }
    addLine(
      "r1-sujood-2", .firstRakah, .prostrating,
      JourneyText(
        "Say Allahu Akbar and prostrate a second time, saying",
        "قل الله أكبر واسجد مرة ثانية وقل"),
      try line(19, 41), category: 19, essential: true)

    // Second rak'ah
    add(
      "r2-stand", .secondRakah, .standing,
      JourneyText(
        "Say Allahu Akbar and stand up for the second rak'ah",
        "قل الله أكبر وقم إلى الركعة الثانية"),
      arabic: takbirArabic, english: takbirEnglish, transliteration: takbirLatin, essential: true)
    add(
      "r2-fatiha", .secondRakah, .standing, JourneyText("Recite Al-Fatiha", "اقرأ سورة الفاتحة"),
      arabic: fatihaArabic, english: fatihaEnglish, essential: true)
    add(
      "r2-surah", .secondRakah, .standing,
      JourneyText(
        "Then recite another short surah, for example Al-Kawthar",
        "ثم اقرأ سورة قصيرة أخرى، مثل سورة الكوثر"),
      arabic: kawtharArabic, english: kawtharEnglish, essential: true)
    addLine(
      "r2-bow", .secondRakah, .bowing,
      JourneyText("Bow as before and say", "اركع كما في الركعة الأولى وقل"),
      try line(17, 33), category: 17, essential: true)
    addLine(
      "r2-rise", .secondRakah, .rising, JourneyText("Rise and say", "ارفع وقل"),
      try line(18, 38), category: 18, essential: true)
    addLine(
      "r2-rise-2", .secondRakah, .rising, thenSay, try line(18, 39), category: 18, essential: true)
    addLine(
      "r2-sujood", .secondRakah, .prostrating, JourneyText("Prostrate and say", "اسجد وقل"),
      try line(19, 41), category: 19, essential: true)
    addLine(
      "r2-sit", .secondRakah, .sitting, JourneyText("Sit and say", "اجلس وقل"),
      try line(20, 48), category: 20, essential: true)
    addLine(
      "r2-sujood-2", .secondRakah, .prostrating,
      JourneyText("Prostrate a second time and say", "اسجد مرة ثانية وقل"),
      try line(19, 41), category: 19, essential: true)

    // Closing
    try addLines(
      22, prefix: "closing", .closing, .tashahhud,
      first: JourneyText(
        "Sit, point your right index finger, and say", "اجلس وأشر بسبابتك اليمنى وقل")
    ) { _ in true }
    try addLines(
      23, prefix: "closing", .closing, .tashahhud,
      first: JourneyText("Then send blessings on the Prophet", "ثم صلِّ على النبي ﷺ")
    ) { $0 == 53 }
    try addLines(
      24, prefix: "closing", .closing, .tashahhud,
      first: JourneyText("Then make supplication, for example", "ثم ادعُ بما شئت، مثل"),
      rest: thenSay
    ) { $0 == 55 }
    let salamArabic = "السَّلَامُ عَلَيْكُمْ وَرَحْمَةُ اللَّهِ"
    let salamEnglish = "Peace and the mercy of Allah be upon you"
    let salamLatin = "As-salamu alaykum wa rahmatullah"
    add(
      "salam-right", .closing, .salamRight,
      JourneyText("Turn your head to the right and say", "التفت برأسك يميناً وقل"),
      arabic: salamArabic, english: salamEnglish, transliteration: salamLatin, essential: true)
    add(
      "salam-left", .closing, .salamLeft,
      JourneyText("Then turn your head to the left and say the same", "ثم التفت يساراً وقل مثلها"),
      arabic: salamArabic, english: salamEnglish, transliteration: salamLatin, essential: true)

    // After the prayer
    try addLines(
      25, prefix: "after", .afterPrayer, .after,
      first: JourneyText("After the salam, say", "بعد التسليم قل"), rest: thenSay
    ) { $0 == 66 || $0 == 69 }

    let chosen = kids ? raw.filter(\.isEssential) : raw
    var result: [GuideStep] = []
    var previous: GuidePosture?
    var seenCategories: Set<Int> = []
    for step in chosen {
      let clips: [GuideClip]
      if let previous, previous != step.posture {
        clips = GuideClip.path(from: previous, to: step.posture)
      } else {
        clips = []
      }
      // The first line kept from a chapter carries that chapter's instruction,
      // so kids mode never opens a chapter with "Or say".
      var instruction = step.instruction
      if let category = step.sourceCategoryID, step.sourceLineID != nil,
        !seenCategories.contains(category), step.id.hasPrefix("r1-") || step.id.hasPrefix("closing-")
          || step.id.hasPrefix("after-")
      {
        seenCategories.insert(category)
        if let first = firstInstructions[category] { instruction = first }
      }
      result.append(
        GuideStep(
          id: step.id, section: step.section, posture: step.posture, enterClips: clips,
          instruction: instruction, arabic: step.arabic, translated: step.translated,
          transliteration: step.transliteration, repeatCount: step.repeatCount,
          isEssential: step.isEssential, sourceCategoryID: step.sourceCategoryID,
          sourceLineID: step.sourceLineID))
      previous = step.posture
    }
    return result
  }
}
