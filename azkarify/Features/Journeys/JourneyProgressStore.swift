import Combine
import Foundation

struct JourneyProgress: Codable, Equatable {
  var completedSteps: Set<String> = []
  var choices: [String: String] = [:]
}

enum JourneyStepUpdate: Equatable {
  case unchanged
  case reopened
  case progressed
  case completedJourney
}

@MainActor
final class JourneyProgressStore: ObservableObject {
  static let stepPoints = 10
  static let journeyCompletionPoints = 25
  static let slideshowCompletionPoints = 30

  @Published private var payload: StoredPayload
  private let defaults: UserDefaults
  private let calendar: Calendar

  private static let storageKey = "journey-progress.v2"
  private static let legacyStorageKey = "journey-progress.v1"
  private static let payloadVersion = 2

  init(defaults: UserDefaults = .standard, calendar: Calendar = .autoupdatingCurrent) {
    self.defaults = defaults
    self.calendar = calendar

    if let data = defaults.data(forKey: Self.storageKey),
      let stored = try? JSONDecoder().decode(StoredPayload.self, from: data),
      stored.version == Self.payloadVersion
    {
      payload = stored
    } else if let data = defaults.data(forKey: Self.legacyStorageKey),
      let legacyRecords = try? JSONDecoder().decode(
        [String: [String: JourneyProgress]].self, from: data)
    {
      payload = StoredPayload(
        version: Self.payloadVersion,
        records: legacyRecords,
        awards: Self.legacyAwards(for: legacyRecords))
      persist()
    } else {
      payload = StoredPayload(version: Self.payloadVersion, records: [:], awards: [:])
    }
  }

  var totalPoints: Int {
    payload.awards.values.reduce(0) { $0 + $1.amount }
  }

  func pointsEarned(on date: Date = Date()) -> Int {
    let key = dayKey(date)
    return payload.awards.values
      .filter { $0.dayKey == key }
      .reduce(0) { $0 + $1.amount }
  }

  func recordCounterTap(on date: Date = Date()) {
    var updatedPayload = payload
    let taps = (updatedPayload.counterTapRemainder ?? 0) + 1
    updatedPayload.counterTapRemainder = taps % 33
    if taps == 33 {
      let id = "counter|\(UUID().uuidString)"
      updatedPayload.awards[id] = PointsAward(
        id: id, dayKey: dayKey(date), sourceID: "counter", stepID: nil,
        timestamp: date, amount: 1, reason: "counter-33-completed")
    }
    save(updatedPayload)
  }

  func progress(for journey: JourneyDefinition, on date: Date = Date()) -> JourneyProgress {
    payload.records[dayKey(date)]?[journey.id] ?? JourneyProgress()
  }

  func isComplete(_ step: JourneyStep, in journey: JourneyDefinition, on date: Date = Date())
    -> Bool
  {
    let progress = progress(for: journey, on: date)
    return Self.isComplete(step, in: progress)
  }

  func completedCount(for journey: JourneyDefinition, on date: Date = Date()) -> Int {
    journey.requiredSteps.filter { isComplete($0, in: journey, on: date) }.count
  }

  func isComplete(_ journey: JourneyDefinition, on date: Date = Date()) -> Bool {
    completedCount(for: journey, on: date) == journey.requiredSteps.count
  }

  func completedJourneyCount(on date: Date = Date()) -> Int {
    JourneyCatalog.all.filter { isComplete($0, on: date) }.count
  }

  func dayProgress(on date: Date = Date()) -> Double {
    let requiredStepCount = JourneyCatalog.all.reduce(0) { total, journey in
      total + journey.requiredSteps.count
    }
    guard requiredStepCount > 0 else { return 0 }

    let completedStepCount = JourneyCatalog.all.reduce(0) { total, journey in
      total + journey.requiredSteps.filter { isComplete($0, in: journey, on: date) }.count
    }

    return min(max(Double(completedStepCount) / Double(requiredStepCount), 0), 1)
  }

  @discardableResult
  func toggle(_ step: JourneyStep, in journey: JourneyDefinition, on date: Date = Date())
    -> JourneyStepUpdate
  {
    guard journey.steps.contains(where: { $0.id == step.id }) else { return .unchanged }

    var updatedPayload = payload
    var progress = updatedPayload.records[dayKey(date)]?[journey.id] ?? JourneyProgress()
    guard step.options.isEmpty || step.options.contains(where: { $0.id == progress.choices[step.id] })
    else { return .unchanged }

    if progress.completedSteps.contains(step.id) {
      progress.completedSteps.remove(step.id)
      updatedPayload.records[dayKey(date), default: [:]][journey.id] = progress
      save(updatedPayload)
      return .reopened
    }

    let wasJourneyComplete = Self.isComplete(journey, in: progress)
    progress.completedSteps.insert(step.id)
    let isJourneyComplete = Self.isComplete(journey, in: progress)
    let dateKey = dayKey(date)

    let stepAwardID = Self.stepAwardID(
      dateKey: dateKey, journeyID: journey.id, stepID: step.id)
    if updatedPayload.awards[stepAwardID] == nil {
      let award = PointsAward(
        id: stepAwardID,
        dayKey: dateKey,
        sourceID: journey.id,
        stepID: step.id,
        timestamp: date,
        amount: Self.stepPoints,
        reason: "journey-step-completed")
      updatedPayload.awards[award.id] = award
    }

    if !wasJourneyComplete && isJourneyComplete {
      let bonusAwardID = Self.bonusAwardID(dateKey: dateKey, journeyID: journey.id)
      if updatedPayload.awards[bonusAwardID] == nil {
        let award = PointsAward(
          id: bonusAwardID,
          dayKey: dateKey,
          sourceID: journey.id,
          stepID: nil,
          timestamp: date,
          amount: Self.journeyCompletionPoints,
          reason: "journey-completed")
        updatedPayload.awards[award.id] = award
      }
    }

    updatedPayload.records[dayKey(date), default: [:]][journey.id] = progress
    save(updatedPayload)
    return !wasJourneyComplete && isJourneyComplete ? .completedJourney : .progressed
  }

  func choose(
    _ option: JourneyStepOption,
    for step: JourneyStep,
    in journey: JourneyDefinition,
    on date: Date = Date())
  {
    guard journey.steps.contains(where: { $0.id == step.id }), step.options.contains(option) else {
      return
    }

    var updatedPayload = payload
    var progress = updatedPayload.records[dayKey(date)]?[journey.id] ?? JourneyProgress()
    if progress.choices[step.id] != option.id {
      progress.completedSteps.remove(step.id)
    }
    progress.choices[step.id] = option.id
    updatedPayload.records[dayKey(date), default: [:]][journey.id] = progress
    save(updatedPayload)
  }

  @discardableResult
  func completeSlideshow(categoryID: Int, on date: Date = Date()) -> Bool {
    let dateKey = dayKey(date)
    let awardID = "slideshow|\(dateKey)|\(categoryID)"
    guard payload.awards[awardID] == nil else { return false }

    var updatedPayload = payload
    updatedPayload.awards[awardID] = PointsAward(
      id: awardID,
      dayKey: dateKey,
      sourceID: "slideshow|\(categoryID)",
      stepID: nil,
      timestamp: date,
      amount: Self.slideshowCompletionPoints,
      reason: "slideshow-completed")
    save(updatedPayload)
    return true
  }

  private func save(_ updatedPayload: StoredPayload) {
    payload = updatedPayload
    persist()
  }

  private func persist() {
    guard let data = try? JSONEncoder().encode(payload) else { return }
    defaults.set(data, forKey: Self.storageKey)
  }

  private func dayKey(_ date: Date) -> String {
    let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
    return "\(components.era ?? 1)-\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
  }

  private static func isComplete(_ step: JourneyStep, in progress: JourneyProgress) -> Bool {
    guard progress.completedSteps.contains(step.id) else { return false }
    return step.options.isEmpty || step.options.contains { $0.id == progress.choices[step.id] }
  }

  private static func isComplete(_ journey: JourneyDefinition, in progress: JourneyProgress) -> Bool {
    journey.requiredSteps.allSatisfy { isComplete($0, in: progress) }
  }

  private static func stepAwardID(dateKey: String, journeyID: String, stepID: String) -> String {
    "journey-step|\(dateKey)|\(journeyID)|\(stepID)"
  }

  private static func bonusAwardID(dateKey: String, journeyID: String) -> String {
    "journey-bonus|\(dateKey)|\(journeyID)"
  }

  private static func legacyAwards(
    for records: [String: [String: JourneyProgress]]) -> [String: PointsAward]
  {
    var result: [String: PointsAward] = [:]
    let timestamp = Date(timeIntervalSince1970: 0)

    for (dateKey, journeys) in records {
      for (journeyID, progress) in journeys {
        guard let journey = JourneyCatalog.all.first(where: { $0.id == journeyID }) else {
          continue
        }

        for step in journey.steps where isComplete(step, in: progress) {
          let id = stepAwardID(dateKey: dateKey, journeyID: journey.id, stepID: step.id)
          result[id] = PointsAward(
            id: id,
            dayKey: dateKey,
            sourceID: journey.id,
            stepID: step.id,
            timestamp: timestamp,
            amount: 0,
            reason: "legacy-migration")
        }

        if isComplete(journey, in: progress) {
          let id = bonusAwardID(dateKey: dateKey, journeyID: journey.id)
          result[id] = PointsAward(
            id: id,
            dayKey: dateKey,
            sourceID: journey.id,
            stepID: nil,
            timestamp: timestamp,
            amount: 0,
            reason: "legacy-migration")
        }
      }
    }

    return result
  }
}

private struct PointsAward: Codable, Equatable {
  let id: String
  let dayKey: String
  let sourceID: String
  let stepID: String?
  let timestamp: Date
  let amount: Int
  let reason: String

  private enum CodingKeys: String, CodingKey {
    case id, dayKey, stepID, timestamp, amount, reason
    case sourceID = "journeyID"
  }
}

private struct StoredPayload: Codable {
  let version: Int
  var records: [String: [String: JourneyProgress]]
  var awards: [String: PointsAward]
  var counterTapRemainder: Int?
}
