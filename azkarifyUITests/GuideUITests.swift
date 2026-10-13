import XCTest

final class GuideUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testStandingBubbleIsEntry27() {
    let app = launch(language: "en")
    let bubble = app.descendants(matching: .any)["guide.bubble"].firstMatch
    XCTAssertTrue(bubble.waitForExistence(timeout: 15))
    XCTAssertTrue(bubble.label.contains("distance me from my sins"))
    XCTAssertEqual(bubble.value as? String, "16-27")
    XCTAssertTrue(app.descendants(matching: .any)["guide.posture.standing"].firstMatch.exists)
  }

  @MainActor
  func testOpenSheetShowsArabicAndRepeatOne() {
    let app = launch(language: "en")
    XCTAssertTrue(app.buttons["guide.expand"].waitForExistence(timeout: 15))
    app.buttons["guide.expand"].tap()
    XCTAssertTrue(app.descendants(matching: .any)["guide.sheet"].firstMatch.waitForExistence(timeout: 5))
    let arabic = app.descendants(matching: .any)["guide.sheet.arabic"].firstMatch
    XCTAssertTrue(arabic.waitForExistence(timeout: 5))
    XCTAssertTrue(containsArabicScalar(arabic.label))
    XCTAssertEqual(app.descendants(matching: .any)["guide.sheet.repeat"].firstMatch.label, "1")
  }

  @MainActor
  func testNextMovesToEntry28AndKeepsStanding() {
    let app = launch(language: "en")
    let bubble = app.descendants(matching: .any)["guide.bubble"].firstMatch
    XCTAssertTrue(bubble.waitForExistence(timeout: 15))
    app.buttons["guide.next"].tap()
    XCTAssertTrue(bubble.label.contains("How perfect You are O Allah"))
    XCTAssertEqual(bubble.value as? String, "16-28")
    XCTAssertTrue(app.descendants(matching: .any)["guide.posture.standing"].firstMatch.exists)
  }

  @MainActor
  func testBackReturnsToEntry27() {
    let app = launch(language: "en")
    let bubble = app.descendants(matching: .any)["guide.bubble"].firstMatch
    XCTAssertTrue(bubble.waitForExistence(timeout: 15))
    app.buttons["guide.next"].tap()
    XCTAssertEqual(bubble.value as? String, "16-28")
    app.buttons["guide.back"].tap()
    XCTAssertTrue(bubble.label.contains("distance me from my sins"))
    XCTAssertEqual(bubble.value as? String, "16-27")
  }

  @MainActor
  func testNextDisabledOnEntry32() {
    let app = launch(language: "en")
    let next = app.buttons["guide.next"]
    XCTAssertTrue(next.waitForExistence(timeout: 15))
    for _ in 0..<5 { next.tap() }
    let bubble = app.descendants(matching: .any)["guide.bubble"].firstMatch
    XCTAssertEqual(bubble.value as? String, "16-32")
    XCTAssertFalse(next.isEnabled)
  }

  @MainActor
  func testArabicBubbleShowsArabicScript() {
    let app = launch(language: "ar")
    let bubble = app.descendants(matching: .any)["guide.bubble"].firstMatch
    XCTAssertTrue(bubble.waitForExistence(timeout: 15))
    XCTAssertEqual(bubble.value as? String, "16-27")
    XCTAssertTrue(containsArabicScalar(bubble.label))
  }

  @MainActor
  func testCloseReturnsHomeWithoutCompletingFajr() {
    let app = launch(language: "en")
    XCTAssertTrue(app.buttons["guide.close"].waitForExistence(timeout: 15))
    app.buttons["guide.close"].tap()
    let bubble = app.descendants(matching: .any)["guide.bubble"].firstMatch
    let gone = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"), object: bubble)
    XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 5), .completed)
    let journeys = app.buttons["dailyJourneys"]
    XCTAssertTrue(journeys.waitForExistence(timeout: 15))
    XCTAssertTrue(journeys.isHittable)
    journeys.tap()
    let fajr = app.buttons["journey-prayer-fajr"]
    reveal(fajr, in: app)
    fajr.tap()
    let completion = app.staticTexts["journey-completion"]
    XCTAssertTrue(completion.waitForExistence(timeout: 5))
    XCTAssertNotEqual(completion.label, "Journey complete")
  }

  @MainActor
  private func launch(language: String) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "-AppleLanguages", "(\(language))",
      "-AppleLocale", "en_AE",
      "-hasSeenIntro", "YES",
      "-hasPresentedPrayerLocationSetup", "YES",
      "-showGuide", "YES",
    ]
    app.launch()
    return app
  }

  @MainActor
  private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    for _ in 0..<12 {
      if element.exists && element.isHittable { return }
      app.swipeUp()
    }
    XCTAssertTrue(element.exists && element.isHittable, "Expected control to be reachable by scrolling")
  }

  private func containsArabicScalar(_ text: String) -> Bool {
    text.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) }
  }
}
