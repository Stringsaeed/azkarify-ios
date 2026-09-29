//
//  azkarifyUITests.swift
//  azkarifyUITests
//
//  Created by Muhammed Saeed on 29/09/2026.
//

import XCTest

final class azkarifyUITests: XCTestCase {

  @MainActor
  func testArabicAppearanceAndSlideshow() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "-language", "ar", "-font", "amiri", "-accent", "teal", "-hasSeenIntro", "YES",
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
    app.launchArguments = ["-language", "ar", "-font", "amiri", "-hasSeenIntro", "YES"]
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
    app.launchArguments = ["-language", "ar", "-hasSeenIntro", "YES"]
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
    app.launchArguments = ["-language", "en", "-hasSeenIntro", "YES"]
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
  func testArabicFontSelectionUpdatesHeader() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-language", "ar", "-hasSeenIntro", "YES"]
    app.launch()
    app.buttons["الإعدادات"].tap()
    app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "الخط")).firstMatch.tap()
    app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "أميري")).firstMatch.tap()
    XCTAssertTrue(app.staticTexts["الإعدادات"].waitForExistence(timeout: 5))
    let image = XCTAttachment(screenshot: app.screenshot())
    image.name = "Settings after selecting Amiri"
    image.lifetime = .keepAlways
    add(image)
  }

}
