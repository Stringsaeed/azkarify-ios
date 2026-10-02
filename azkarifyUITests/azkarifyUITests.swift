//
//  azkarifyUITests.swift
//  azkarifyUITests
//
//  Created by Muhammed Saeed on 29/09/2026.
//

import XCTest

final class azkarifyUITests: XCTestCase {

  @MainActor
  func testAdaptiveCategoryNavigation() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(en)", "-hasSeenIntro", "YES", "-hasPresentedPrayerLocationSetup", "YES"]
    app.launch()
    let morning = app.buttons["Words of remembrance for morning and evening"].firstMatch
    let sleeping = app.buttons["What to say before sleeping"].firstMatch
    XCTAssertTrue(morning.waitForExistence(timeout: 15))
    morning.tap()
    XCTAssertTrue(app.buttons["Slideshow"].waitForExistence(timeout: 5))

    if app.frame.width >= 700 {
      XCTAssertTrue(sleeping.isHittable, "The sidebar should remain available beside the azkar")
      XCTAssertTrue(morning.isSelected)
    } else {
      XCTAssertFalse(sleeping.isHittable)
      let back = app.buttons["BackButton"]
      if back.exists {
        back.tap()
      } else {
        app.navigationBars.buttons.firstMatch.tap()
      }
      XCTAssertTrue(sleeping.waitForExistence(timeout: 5))
    }
    sleeping.tap()
    XCTAssertTrue(app.buttons["Slideshow"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["What to say before sleeping"].firstMatch.exists)
    let image = XCTAttachment(screenshot: app.screenshot())
    image.name = "Adaptive category navigation"
    image.lifetime = .keepAlways
    add(image)
  }

  @MainActor
  func testArabicAppearanceAndSlideshow() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "-AppleLanguages", "(ar)", "-accent", "teal", "-hasSeenIntro", "YES", "-hasPresentedPrayerLocationSetup", "YES",
    ]
    app.launch()
    XCTAssertTrue(app.staticTexts["حصن المسلم"].waitForExistence(timeout: 15))

    app.buttons["الإعدادات"].tap()
    XCTAssertTrue(app.staticTexts["الإعدادات"].waitForExistence(timeout: 5))
    let settingsImage = XCTAttachment(screenshot: app.screenshot())
    settingsImage.name = "Arabic Settings"
    settingsImage.lifetime = .keepAlways
    add(settingsImage)

    app.buttons["لون التمييز"].tap()
    XCTAssertTrue(app.staticTexts["لون التمييز"].waitForExistence(timeout: 5))
    let accentImage = XCTAttachment(screenshot: app.screenshot())
    accentImage.name = "Accent choices"
    accentImage.lifetime = .keepAlways
    add(accentImage)

    app.buttons["فيروزي"].tap()

    app.navigationBars["الإعدادات"].buttons.firstMatch.tap()
    app.buttons["أذكار الصباح والمساء"].firstMatch.tap()
    app.buttons["عرض الشرائح"].tap()
    let slideshowImage = XCTAttachment(screenshot: app.screenshot())
    slideshowImage.name = "Arabic slideshow first page"
    slideshowImage.lifetime = .keepAlways
    add(slideshowImage)
  }

  @MainActor
  func testAccentSelectionUpdatesSettings() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(ar)", "-hasSeenIntro", "YES", "-hasPresentedPrayerLocationSetup", "YES"]
    app.launch()
    app.buttons["الإعدادات"].tap()
    app.buttons["لون التمييز"].tap()
    app.buttons["أزرق"].tap()
    let image = XCTAttachment(screenshot: app.screenshot())
    image.name = "Settings after selecting blue"
    image.lifetime = .keepAlways
    add(image)
    app.buttons["لون التمييز"].tap()
    XCTAssertTrue(app.buttons["أزرق"].isSelected)
  }

  @MainActor
  func testArabicMenuUsesBeadsIcon() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(ar)", "-hasSeenIntro", "YES", "-hasPresentedPrayerLocationSetup", "YES"]
    app.launch()
    app.buttons["القائمة"].tap()
    let image = XCTAttachment(screenshot: app.screenshot())
    image.name = "Arabic menu"
    image.lifetime = .keepAlways
    add(image)
    app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "السبحة")).firstMatch.tap()
    XCTAssertTrue(app.buttons["العدد: 0"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testAddingFavoriteShowsIndicator() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(en)", "-hasSeenIntro", "YES", "-hasPresentedPrayerLocationSetup", "YES"]
    app.launch()
    let addButton = app.buttons["Add to favorites"].firstMatch
    XCTAssertTrue(addButton.waitForExistence(timeout: 15))
    addButton.tap()
    XCTAssertTrue(app.buttons["Remove from favorites"].firstMatch.waitForExistence(timeout: 5))
    let image = XCTAttachment(screenshot: app.screenshot())
    image.name = "Favorite added indicator"
    image.lifetime = .keepAlways
    add(image)
  }

  @MainActor
  func testCounterKeepsFullZikrScrollable() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(ar)", "-hasSeenIntro", "YES", "-hasPresentedPrayerLocationSetup", "YES"]
    app.launch()
    app.buttons["أذكار الصباح والمساء"].firstMatch.tap()
    let counterButton = app.buttons.matching(
      NSPredicate(format: "label CONTAINS %@", "ابدأ العد من 3")
    ).firstMatch
    XCTAssertTrue(counterButton.waitForExistence(timeout: 15))
    counterButton.tap()

    let zikrScroll = app.scrollViews["counterZikrScroll"]
    XCTAssertTrue(zikrScroll.waitForExistence(timeout: 5))
    let expanded = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in zikrScroll.frame.height > app.frame.height * 0.75 },
      object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [expanded], timeout: 5), .completed)
    let before = XCTAttachment(screenshot: app.screenshot())
    before.name = "Counter zikr beginning"
    before.lifetime = .keepAlways
    add(before)

    zikrScroll.swipeUp()
    XCTAssertTrue(app.buttons["العدد: 3"].waitForExistence(timeout: 5))
    let after = XCTAttachment(screenshot: app.screenshot())
    after.name = "Counter zikr ending"
    after.lifetime = .keepAlways
    add(after)
  }

}
