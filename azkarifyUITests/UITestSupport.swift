import XCTest

/// The app's four tabs, by accessibility identifier.
enum AppTab: String {
  case today = "tab.today"
  case azkar = "tab.azkar"
  case counter = "tab.counter"
  case settings = "tab.settings"
}

extension XCUIApplication {
  /// Launches past the intro and the location sheet and waits for the tab bar.
  @MainActor
  static func launchConfigured(language: String, extraArguments: [String] = []) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "-AppleLanguages", "(\(language))", "-hasSeenIntro", "YES", "-hasPresentedPrayerLocationSetup", "YES",
    ] + extraArguments
    app.launch()
    XCTAssertTrue(app.buttons[AppTab.today.rawValue].waitForExistence(timeout: 15))
    return app
  }

  @MainActor
  func open(_ tab: AppTab) {
    let button = buttons[tab.rawValue]
    XCTAssertTrue(button.waitForExistence(timeout: 10))
    button.tap()
  }

  /// Opens a Hisn category from the Azkar tab and waits for the reader.
  @MainActor
  func openCategory(id: Int) {
    let row = descendants(matching: .any)["category-\(id)"].firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 15))
    reveal(row)
    row.tap()
    XCTAssertTrue(buttons["focusMode"].waitForExistence(timeout: 5))
  }

  /// The Azkar search field sits under the large title until the list is pulled down.
  @MainActor
  func azkarSearchField() -> XCUIElement {
    let field = searchFields.firstMatch
    if !field.waitForExistence(timeout: 3) {
      descendants(matching: .any)["azkarSidebar"].firstMatch.swipeDown()
    }
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    return field
  }

  /// Opens the category whose title matches `title` by searching for `query`.
  @MainActor
  func searchAndOpenCategory(_ query: String, title: String) {
    let search = azkarSearchField()
    search.tap()
    if buttons["Clear text"].exists { buttons["Clear text"].tap() }
    search.typeText(query)
    let row = staticTexts[title].firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    row.tap()
    XCTAssertTrue(buttons["focusMode"].waitForExistence(timeout: 5))
  }

  @MainActor
  func goBack() {
    let back = buttons["BackButton"]
    if back.exists {
      back.tap()
    } else {
      navigationBars.buttons.firstMatch.tap()
    }
  }

  /// Finishing a journey or a focus session presents one celebration sheet.
  @MainActor
  func dismissCompletionSheet() {
    let done = buttons["completion.done"]
    XCTAssertTrue(done.waitForExistence(timeout: 5), "Expected the completion sheet")
    done.tap()
    let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: done)
    XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 5), .completed)
  }

  @MainActor
  func reveal(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    for _ in 0..<12 {
      if element.exists && element.isHittable { return }
      swipeUp()
    }
    XCTAssertTrue(
      element.exists && element.isHittable, "Expected control to be reachable by scrolling", file: file, line: line)
  }
}

extension XCTestCase {
  @MainActor
  func attachScreenshot(_ app: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor
  func waitForSelection(_ element: XCUIElement, selected: Bool) {
    let expectation = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "selected == %@", NSNumber(value: selected)), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
  }
}
