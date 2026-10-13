import Foundation
import Testing

@testable import azkarify

struct GuideScriptTests {
  @MainActor
  private func steps(_ language: String, kids: Bool) throws -> [GuideStep] {
    try GuideScript.steps(language: language, repository: AzkarRepository(), kids: kids)
  }

  @MainActor
  @Test func fullCountMatchesAcrossLanguages() throws {
    let english = try steps("en", kids: false)
    let arabic = try steps("ar", kids: false)
    #expect(english.count == arabic.count)
    let kids = try steps("en", kids: true)
    print("en full \(english.count), en kids \(kids.count)")
  }

  @MainActor
  @Test func kidsModeIsShorterAndEssential() throws {
    let full = try steps("en", kids: false)
    let kids = try steps("en", kids: true)
    #expect(kids.count < full.count)
    #expect(kids.allSatisfy { $0.isEssential })
  }

  @MainActor
  @Test func startsAndEnds() throws {
    for kidsMode in [false, true] {
      let list = try steps("en", kids: kidsMode)
      let first = try #require(list.first)
      let last = try #require(list.last)
      #expect(first.id == "r1-stand")
      #expect(first.posture == .standing)
      #expect(last.sourceCategoryID == 25)
      #expect(last.sourceLineID == (kidsMode ? 69 : 73))
      #expect(last.posture == .after)
    }
  }

  @MainActor
  @Test func clipChainsAreContinuous() throws {
    for kidsMode in [false, true] {
      let list = try steps("en", kids: kidsMode)
      let head = try #require(list.first)
      #expect(head.enterClips.isEmpty)
      for (previous, step) in zip(list, list.dropFirst()) {
        if previous.posture == step.posture {
          #expect(step.enterClips.isEmpty)
        } else {
          #expect(step.enterClips.first?.from == previous.posture)
          #expect(step.enterClips.last?.to == step.posture)
          for (a, b) in zip(step.enterClips, step.enterClips.dropFirst()) {
            #expect(a.to == b.from)
          }
        }
      }
    }
  }

  @MainActor
  @Test func specificClips() throws {
    for kidsMode in [false, true] {
      let list = try steps("en", kids: kidsMode)
      let sujood2 = try #require(list.first { $0.id == "r1-sujood-2" })
      #expect(sujood2.enterClips == [GuideClip(from: .sitting, to: .prostrating)])
      let r2 = try #require(list.first { $0.id == "r2-stand" })
      #expect(
        r2.enterClips == [
          GuideClip(from: .prostrating, to: .sitting), GuideClip(from: .sitting, to: .standing),
        ])
    }
  }

  @MainActor
  @Test func kidsPostureSequence() throws {
    let list = try steps("en", kids: true)
    var sequence: [GuidePosture] = []
    for step in list where sequence.last != step.posture { sequence.append(step.posture) }
    #expect(
      sequence == [
        .standing, .takbir, .standing, .bowing, .rising, .prostrating, .sitting, .prostrating,
        .standing, .bowing, .rising, .prostrating, .sitting, .prostrating, .tashahhud,
        .salamRight, .salamLeft, .after,
      ])
  }

  @MainActor
  @Test func languageContent() throws {
    let arabic = try steps("ar", kids: false)
    #expect(arabic.allSatisfy { $0.translated.isEmpty && $0.transliteration.isEmpty })
    let english = try steps("en", kids: false)
    let bow = try #require(english.first { $0.sourceCategoryID == 17 && $0.sourceLineID == 33 })
    #expect(!bow.transliteration.isEmpty)
  }

  @MainActor
  @Test func idsAreUnique() throws {
    for kidsMode in [false, true] {
      let ids = try steps("en", kids: kidsMode).map(\.id)
      #expect(Set(ids).count == ids.count)
    }
  }
}
