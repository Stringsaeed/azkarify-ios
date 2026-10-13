import XCTest

final class GuideUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testStepsSheetModeAndCloseInEnglish() {
    let app = launch(language: "en")
    let bubble = element("guide.bubble", in: app)
    let stage = element("guide.stage", in: app)
    XCTAssertTrue(bubble.waitForExistence(timeout: 15))
    waitForValue(bubble, "r1-stand")
    XCTAssertTrue(stage.exists)
    waitForValue(stage, "standing")
    attachScreenshot(app, name: "Guide first step")

    let next = app.buttons["guide.next"]
    let back = app.buttons["guide.back"]
    XCTAssertFalse(back.isEnabled)
    next.tap()
    waitForValue(bubble, "r1-takbir")
    waitForValue(stage, "takbir")
    XCTAssertTrue(back.isEnabled)
    back.tap()
    waitForValue(bubble, "r1-stand")
    waitForValue(stage, "standing")

    next.tap()
    waitForValue(bubble, "r1-takbir")
    app.buttons["guide.expand"].tap()
    let sheet = element("guide.sheet", in: app)
    XCTAssertTrue(sheet.waitForExistence(timeout: 5))
    let arabic = element("guide.sheet.arabic", in: app)
    XCTAssertTrue(arabic.waitForExistence(timeout: 5))
    XCTAssertTrue(containsArabic(arabic.label), "Expected Arabic script, got \(arabic.label)")
    XCTAssertEqual(element("guide.sheet.repeat", in: app).label, "1")
    attachScreenshot(app, name: "Guide step sheet")
    sheet.swipeDown(velocity: .fast)
    if !waitForNonExistence(sheet, timeout: 3) {
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
      XCTAssertTrue(waitForNonExistence(sheet, timeout: 5))
    }

    let mode = element("guide.mode", in: app)
    XCTAssertTrue(mode.waitForExistence(timeout: 5))
    if (mode.value as? String) == "full" {
      mode.tap()
      waitForValue(mode, "kids")
    }
    let progress = element("guide.progress", in: app)
    let kidsTotal = total(in: progress.label)
    XCTAssertNotNil(kidsTotal)
    mode.tap()
    waitForValue(mode, "full")
    let grew = NSPredicate { _, _ in
      guard let kidsTotal, let fullTotal = self.total(in: progress.label) else { return false }
      return fullTotal > kidsTotal
    }
    wait(for: [expectation(for: grew, evaluatedWith: nil)], timeout: 5)
    // Leave the default short guide for the next run.
    mode.tap()
    waitForValue(mode, "kids")

    app.buttons["guide.close"].tap()
    XCTAssertTrue(waitForNonExistence(bubble, timeout: 5))
    let card = app.buttons["learnToPray"]
    XCTAssertTrue(card.waitForExistence(timeout: 5))
    XCTAssertTrue(card.isHittable)
    attachScreenshot(app, name: "Home with guide card")
    card.tap()
    XCTAssertTrue(bubble.waitForExistence(timeout: 5))
    waitForValue(bubble, "r1-stand")
  }

  @MainActor
  func testArabicBubbleShowsArabicScript() {
    let app = launch(language: "ar")
    let bubble = element("guide.bubble", in: app)
    XCTAssertTrue(bubble.waitForExistence(timeout: 15))
    XCTAssertTrue(containsArabic(bubble.label), "Expected Arabic script, got \(bubble.label)")
    app.buttons["guide.next"].tap()
    waitForValue(bubble, "r1-takbir")
    XCTAssertTrue(bubble.label.contains("اللهُ أَكْبَرُ"))
    attachScreenshot(app, name: "Arabic guide")
  }

  @MainActor
  private func launch(language: String) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "-AppleLanguages", "(\(language))", "-hasSeenIntro", "YES",
      "-hasPresentedPrayerLocationSetup", "YES", "-showGuide", "YES",
    ]
    app.launch()
    return app
  }

  private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: identifier).firstMatch
  }

  private func waitForValue(_ element: XCUIElement, _ value: String) {
    let predicate = NSPredicate(format: "value == %@", value)
    let result = XCTWaiter().wait(
      for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 5)
    XCTAssertEqual(result, .completed, "Expected value \(value), got \(String(describing: element.value))")
  }

  private func waitForNonExistence(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
    let predicate = NSPredicate(format: "exists == false")
    let result = XCTWaiter().wait(
      for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout)
    return result == .completed
  }

  private func total(in label: String) -> Int? {
    let numbers = label.split { !$0.isNumber }.compactMap { Int($0) }
    return numbers.count == 2 ? numbers[1] : nil
  }

  private func containsArabic(_ text: String) -> Bool {
    text.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) }
  }

  @MainActor
  private func attachScreenshot(_ app: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
