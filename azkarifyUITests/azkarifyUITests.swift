//
//  azkarifyUITests.swift
//  azkarifyUITests
//
//  Created by Muhammed Saeed on 29/09/2026.
//

import XCTest

final class azkarifyUITests: XCTestCase {
  private let morningAndEvening = 27
  private let beforeSleeping = 28

  @MainActor
  func testAdaptiveCategoryNavigation() throws {
    let app = XCUIApplication.launchConfigured(language: "en")
    app.open(.azkar)
    app.openCategory(id: morningAndEvening)
    let sleeping = app.descendants(matching: .any)["category-\(beforeSleeping)"].firstMatch

    if app.frame.width >= 700 {
      XCTAssertTrue(sleeping.isHittable, "The list should remain available beside the azkar")
    } else {
      XCTAssertFalse(sleeping.exists && sleeping.isHittable)
      app.goBack()
      XCTAssertTrue(sleeping.waitForExistence(timeout: 5))
    }
    sleeping.tap()
    XCTAssertTrue(app.buttons["focusMode"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["What to say before sleeping"].firstMatch.exists)
    attachScreenshot(app, name: "Adaptive category navigation")
  }

  @MainActor
  func testArabicAppearanceAndFocusMode() throws {
    let app = XCUIApplication.launchConfigured(language: "ar", extraArguments: ["-accent", "teal"])

    app.open(.settings)
    XCTAssertTrue(app.staticTexts["الإعدادات"].firstMatch.waitForExistence(timeout: 5))
    let teal = app.buttons["accent.teal"]
    XCTAssertTrue(teal.waitForExistence(timeout: 5))
    XCTAssertTrue(teal.isSelected)
    XCTAssertEqual(teal.label, "فيروزي")
    attachScreenshot(app, name: "Arabic Settings")

    app.open(.azkar)
    app.openCategory(id: morningAndEvening)
    app.buttons["focusMode"].tap()
    let progress = app.staticTexts["slideshowProgress"]
    XCTAssertTrue(progress.waitForExistence(timeout: 5))
    let focusImage = XCTAttachment(screenshot: app.screenshot())
    let progressY = progress.frame.midY
    let next = app.buttons["slideshowNext"]
    let previous = app.buttons["slideshowPrevious"]
    XCTAssertTrue(next.label.contains("التالي"))
    XCTAssertTrue(previous.label.contains("السابق"))
    XCTAssertGreaterThan(previous.frame.midX, next.frame.midX)
    next.tap()
    XCTAssertEqual(progress.frame.midY, progressY, accuracy: 1)
    let counter = app.buttons["slideshowCounter"]
    XCTAssertTrue(counter.waitForExistence(timeout: 5))
    previous.tap()
    XCTAssertEqual(progress.label, "١ من ٢٤")
    let counterHidden = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in !counter.exists || !counter.isHittable }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [counterHidden], timeout: 3), .completed)
    focusImage.name = "Arabic focus mode first page"
    focusImage.lifetime = .keepAlways
    add(focusImage)
  }

  @MainActor
  func testFocusModeProgressAndCounterSheet() throws {
    let app = XCUIApplication.launchConfigured(language: "en")
    app.open(.azkar)
    app.openCategory(id: morningAndEvening)
    app.buttons["focusMode"].tap()

    let progress = app.staticTexts["slideshowProgress"]
    XCTAssertTrue(progress.waitForExistence(timeout: 5))
    XCTAssertEqual(progress.label, "1 of 24")
    XCTAssertFalse(app.buttons["slideshowCounter"].exists && app.buttons["slideshowCounter"].isHittable)

    let progressY = progress.frame.midY
    XCTAssertFalse(app.buttons["slideshowPrevious"].isEnabled)
    app.buttons["slideshowNext"].tap()
    XCTAssertEqual(progress.label, "2 of 24")
    XCTAssertEqual(progress.frame.midY, progressY, accuracy: 1)
    XCTAssertTrue(app.buttons["slideshowPrevious"].isEnabled)
    app.buttons["slideshowPrevious"].tap()
    XCTAssertEqual(progress.label, "1 of 24")
    app.buttons["slideshowNext"].tap()
    let counter = app.buttons["slideshowCounter"]
    XCTAssertTrue(counter.waitForExistence(timeout: 5))
    app.reveal(counter)
    counter.tap()
    XCTAssertTrue(app.scrollViews["counterZikrScroll"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Count: 3"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.descendants(matching: .any)["counter.points"].firstMatch.exists)
    attachScreenshot(app, name: "Focus mode counter sheet")
    app.buttons["counter.close"].tap()
    XCTAssertTrue(progress.waitForExistence(timeout: 5))
  }

  @MainActor
  func testFocusModeShowsDotsWithoutProgressForShortSets() throws {
    let app = XCUIApplication.launchConfigured(language: "en")
    app.open(.azkar)
    app.searchAndOpenCategory("completing ablution", title: "What to say upon completing ablution")
    app.buttons["focusMode"].tap()
    let close = app.buttons["focus.close"]
    XCTAssertTrue(close.waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["slideshowProgress"].exists)
    XCTAssertTrue(app.buttons["slideshowNext"].exists)
    XCTAssertTrue(app.buttons["slideshowPrevious"].exists)
    XCTAssertTrue(app.descendants(matching: .any)["slideshowPagination"].firstMatch.exists)
    app.buttons["slideshowNext"].tap()
    app.buttons["slideshowNext"].tap()
    let done = app.buttons["slideshowDone"]
    XCTAssertTrue(done.waitForExistence(timeout: 5))
    XCTAssertTrue(done.label.contains("Done"))
    XCTAssertTrue(close.exists, "The last zikr stays open until Done.")
    done.tap()
    app.dismissCompletionSheet()
    XCTAssertTrue(app.buttons["focusMode"].waitForExistence(timeout: 5))
    XCTAssertFalse(close.exists)
    XCTAssertFalse(app.keyboards.firstMatch.exists)
    attachScreenshot(app, name: "Short focus session finished")
  }

  @MainActor
  func testShortFocusSessionKeepsCounterWithoutProgress() throws {
    let app = XCUIApplication.launchConfigured(language: "ar")
    app.open(.azkar)
    app.searchAndOpenCategory("الرؤيا", title: "ما يفعل من رأى الرؤيا أو الحلم")
    app.buttons["focusMode"].tap()
    let counter = app.buttons["slideshowCounter"]
    XCTAssertTrue(counter.waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["slideshowProgress"].exists)
    app.reveal(counter)
    counter.tap()
    XCTAssertTrue(app.scrollViews["counterZikrScroll"].waitForExistence(timeout: 5))
    attachScreenshot(app, name: "Short focus session keeps counter")
  }

  @MainActor
  func testTwoZikrPaginationAndSingleZikrNavigation() throws {
    let app = XCUIApplication.launchConfigured(language: "en")
    app.open(.azkar)
    app.searchAndOpenCategory("sitting between", title: "Invocations for sitting between two prostrations")
    app.buttons["focusMode"].tap()
    XCTAssertTrue(app.descendants(matching: .any)["slideshowPagination"].firstMatch.waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["slideshowProgress"].exists)
    app.buttons["slideshowNext"].tap()
    XCTAssertTrue(app.buttons["slideshowDone"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["slideshowDone"].label.contains("Done"))
    app.buttons["slideshowPrevious"].tap()
    XCTAssertTrue(app.buttons["slideshowNext"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["slideshowNext"].label.contains("Next"))
    app.buttons["focus.close"].tap()
    XCTAssertTrue(app.buttons["focusMode"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["completion.done"].exists, "Closing early is not a completed session")
    app.goBack()

    app.searchAndOpenCategory("undressing", title: "What to say when undressing")
    app.buttons["focusMode"].tap()
    XCTAssertTrue(app.buttons["focus.close"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["slideshowNext"].exists)
    XCTAssertFalse(app.buttons["slideshowPrevious"].exists)
    XCTAssertFalse(app.descendants(matching: .any)["slideshowPagination"].firstMatch.exists)
    XCTAssertTrue(app.buttons["slideshowDone"].exists)
    app.buttons["slideshowDone"].tap()
    app.dismissCompletionSheet()
    XCTAssertTrue(app.buttons["focusMode"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testAccentSwatchUpdatesSettings() throws {
    let app = XCUIApplication.launchConfigured(language: "ar")
    app.open(.settings)
    let forest = app.buttons["accent.green"]
    let dusk = app.buttons["accent.blue"]
    XCTAssertTrue(dusk.waitForExistence(timeout: 5))
    forest.tap()
    waitForSelection(forest, selected: true)
    dusk.tap()
    waitForSelection(dusk, selected: true)
    waitForSelection(forest, selected: false)
    XCTAssertEqual(dusk.label, "شفقي")
    attachScreenshot(app, name: "Settings after selecting dusk")

    app.terminate()
    app.launch()
    app.open(.settings)
    XCTAssertTrue(dusk.waitForExistence(timeout: 5))
    XCTAssertTrue(dusk.isSelected, "The accent must survive relaunch")
  }

  @MainActor
  func testCounterTabAwardsPointsAndResetDoesNotAward() throws {
    let app = XCUIApplication.launchConfigured(language: "en")
    app.open(.today)
    let points = app.buttons["journey-total-points"]
    XCTAssertTrue(points.waitForExistence(timeout: 15))
    let initialPoints = try XCTUnwrap(Int(points.value as? String ?? ""))

    app.open(.counter)
    let counter = app.buttons["counter.count"]
    XCTAssertTrue(counter.waitForExistence(timeout: 5))
    XCTAssertEqual(counter.label, "Count: 0")
    for _ in 0..<33 { counter.tap() }
    XCTAssertEqual(counter.label, "Count: 33")
    XCTAssertEqual(points.value as? String, String(initialPoints + 1))
    app.buttons["Reset"].tap()
    XCTAssertEqual(counter.label, "Count: 0")
    XCTAssertEqual(points.value as? String, String(initialPoints + 1))

    app.open(.today)
    XCTAssertTrue(points.waitForExistence(timeout: 5))
    XCTAssertEqual(points.value as? String, String(initialPoints + 1))
  }

  @MainActor
  func testArabicCounterTab() throws {
    let app = XCUIApplication.launchConfigured(language: "ar")
    app.open(.counter)
    XCTAssertTrue(app.buttons["العدد: ٠"].waitForExistence(timeout: 5))
    attachScreenshot(app, name: "Arabic counter tab")
    app.buttons["counter.count"].tap()
    XCTAssertTrue(app.buttons["العدد: ١"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testAddingFavoriteUpdatesStar() throws {
    let app = XCUIApplication.launchConfigured(language: "en")
    app.open(.azkar)
    let addButton = app.buttons["Add to favourites"].firstMatch
    XCTAssertTrue(addButton.waitForExistence(timeout: 15))
    let removeButtons = app.buttons.matching(NSPredicate(format: "label == %@", "Remove from favourites"))
    let before = removeButtons.count
    addButton.tap()
    let added = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in removeButtons.count == before + 1 }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [added], timeout: 5), .completed)
    attachScreenshot(app, name: "Favourite added")
  }

  @MainActor
  func testCounterKeepsFullZikrScrollable() throws {
    let app = XCUIApplication.launchConfigured(language: "ar")
    app.open(.azkar)
    app.openCategory(id: morningAndEvening)
    let counterButton = app.buttons.matching(
      NSPredicate(format: "label CONTAINS %@", "العد التنازلي من ٣")
    ).firstMatch
    XCTAssertTrue(counterButton.waitForExistence(timeout: 15))
    app.reveal(counterButton)
    counterButton.tap()

    let zikrScroll = app.scrollViews["counterZikrScroll"]
    XCTAssertTrue(zikrScroll.waitForExistence(timeout: 5))
    let expanded = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in zikrScroll.frame.height > app.frame.height * 0.75 },
      object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [expanded], timeout: 5), .completed)
    attachScreenshot(app, name: "Counter zikr beginning")

    zikrScroll.swipeUp()
    XCTAssertTrue(app.buttons["العدد: ٣"].waitForExistence(timeout: 5))
    attachScreenshot(app, name: "Counter zikr ending")
  }
}
