import XCTest

final class GuideUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testStandingBubbleIsEntry27() {
    let app = launch(language: "en")
    let bubble = guide("guide.bubble", in: app)
    XCTAssertTrue(bubble.waitForExistence(timeout: 15))
    XCTAssertTrue(bubble.label.contains("distance me from my sins"))
    XCTAssertEqual(bubble.value as? String, "16-27")
    XCTAssertTrue(guide("guide.posture.standing", in: app).exists)
    let back = guide("guide.back", in: app)
    XCTAssertTrue(back.waitForExistence(timeout: 5))
    XCTAssertFalse(back.isEnabled)
  }

  @MainActor
  func testOpenSheetShowsArabicAndRepeatOne() {
    let app = launch(language: "en")
    let open = guide("guide.expand", in: app)
    XCTAssertTrue(open.waitForExistence(timeout: 15))
    open.tap()
    XCTAssertTrue(guide("guide.sheet", in: app).waitForExistence(timeout: 5))
    let arabic = guide("guide.sheet.arabic", in: app)
    XCTAssertTrue(arabic.waitForExistence(timeout: 5))
    XCTAssertTrue(containsArabicScalar(arabic.label))
    let count = guide("guide.sheet.repeat", in: app)
    XCTAssertTrue(count.waitForExistence(timeout: 5))
    XCTAssertEqual(count.label, "1")
  }

  @MainActor
  func testNextMovesToEntry28AndKeepsStanding() {
    let app = launch(language: "en")
    let bubble = guide("guide.bubble", in: app)
    XCTAssertTrue(bubble.waitForExistence(timeout: 15))
    let next = guide("guide.next", in: app)
    XCTAssertTrue(next.waitForExistence(timeout: 5))
    next.tap()
    waitForValue("16-28", on: bubble)
    XCTAssertTrue(bubble.label.contains("How perfect You are O Allah"))
    XCTAssertEqual(bubble.value as? String, "16-28")
    XCTAssertTrue(guide("guide.posture.standing", in: app).exists)
  }

  @MainActor
  func testBackReturnsToEntry27() {
    let app = launch(language: "en")
    let bubble = guide("guide.bubble", in: app)
    XCTAssertTrue(bubble.waitForExistence(timeout: 15))
    let next = guide("guide.next", in: app)
    XCTAssertTrue(next.waitForExistence(timeout: 5))
    next.tap()
    waitForValue("16-28", on: bubble)
    let back = guide("guide.back", in: app)
    XCTAssertTrue(back.isEnabled)
    back.tap()
    waitForValue("16-27", on: bubble)
    XCTAssertTrue(bubble.label.contains("distance me from my sins"))
    XCTAssertEqual(bubble.value as? String, "16-27")
  }

  @MainActor
  func testNextDisabledOnEntry32() {
    let app = launch(language: "en")
    let bubble = guide("guide.bubble", in: app)
    XCTAssertTrue(bubble.waitForExistence(timeout: 15))
    let next = guide("guide.next", in: app)
    XCTAssertTrue(next.waitForExistence(timeout: 5))
    for value in ["16-28", "16-29", "16-30", "16-31", "16-32"] {
      XCTAssertTrue(next.isEnabled)
      next.tap()
      waitForValue(value, on: bubble)
    }
    XCTAssertEqual(bubble.value as? String, "16-32")
    XCTAssertTrue(next.exists)
    XCTAssertFalse(next.isEnabled)
  }

  @MainActor
  func testArabicBubbleShowsArabicScript() {
    let app = launch(language: "ar")
    let bubble = guide("guide.bubble", in: app)
    XCTAssertTrue(bubble.waitForExistence(timeout: 15))
    XCTAssertEqual(bubble.value as? String, "16-27")
    XCTAssertTrue(containsArabicScalar(bubble.label))
  }

  @MainActor
  func testCloseReturnsHomeWithoutCompletingFajr() {
    let app = launch(language: "en")
    let close = guide("guide.close", in: app)
    XCTAssertTrue(close.waitForExistence(timeout: 15))
    let bubble = guide("guide.bubble", in: app)
    XCTAssertTrue(bubble.waitForExistence(timeout: 15))
    close.tap()
    let gone = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"), object: bubble)
    XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 5), .completed)
    let journeys = app.descendants(matching: .any)["dailyJourneys"].firstMatch
    XCTAssertTrue(journeys.waitForExistence(timeout: 15))
    let hittable = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "hittable == true"), object: journeys)
    XCTAssertEqual(XCTWaiter.wait(for: [hittable], timeout: 5), .completed)
    journeys.tap()
    let fajr = app.descendants(matching: .any)["journey-prayer-fajr"].firstMatch
    reveal(fajr, in: app)
    fajr.tap()
    let completion = app.descendants(matching: .any)["journey-completion"].firstMatch
    XCTAssertTrue(completion.waitForExistence(timeout: 5))
    XCTAssertEqual(completion.label, "Your progress")
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
  private func guide(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any)[identifier].firstMatch
  }

  @MainActor
  private func waitForValue(_ value: String, on element: XCUIElement) {
    let updated = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value == %@", value), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 5), .completed)
  }

  @MainActor
  private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    for _ in 0..<12 {
      if element.exists && element.isHittable { return }
      app.swipeUp()
    }
    XCTAssertTrue(element.exists && element.isHittable)
  }

  private func containsArabicScalar(_ text: String) -> Bool {
    text.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) }
  }
}
