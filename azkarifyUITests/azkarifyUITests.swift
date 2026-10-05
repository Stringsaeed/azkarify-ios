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

    app.buttons["القائمة"].tap()
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

    if app.frame.width < 700 {
      app.navigationBars["الإعدادات"].buttons.firstMatch.tap()
    }
    app.buttons["أذكار الصباح والمساء"].firstMatch.tap()
    app.buttons["عرض الشرائح"].tap()
    XCTAssertTrue(app.staticTexts["slideshowProgress"].waitForExistence(timeout: 5))
    let slideshowImage = XCTAttachment(screenshot: app.screenshot())
    let progress = app.staticTexts["slideshowProgress"]
    let progressY = progress.frame.midY
    let next = app.buttons["slideshowNext"]
    let previous = app.buttons["slideshowPrevious"]
    XCTAssertTrue(next.label.contains("التالي"))
    XCTAssertTrue(previous.label.contains("السابق"))
    XCTAssertGreaterThan(previous.frame.midX, next.frame.midX)
    next.tap()
    XCTAssertEqual(progress.frame.midY, progressY, accuracy: 1)
    let counter = app.buttons["slideshowCounter"]
    XCTAssertTrue(counter.isHittable)
    XCTAssertGreaterThan(counter.frame.midX, app.frame.midX)
    XCTAssertLessThan(counter.frame.midY, app.frame.height / 3)
    previous.tap()
    XCTAssertEqual(progress.label, "1 من 24")
    let counterHidden = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"), object: counter)
    XCTAssertEqual(XCTWaiter.wait(for: [counterHidden], timeout: 3), .completed)
    slideshowImage.name = "Arabic slideshow first page"
    slideshowImage.lifetime = .keepAlways
    add(slideshowImage)
  }

  @MainActor
  func testSlideshowProgressAndCounterSheet() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(en)", "-hasSeenIntro", "YES", "-hasPresentedPrayerLocationSetup", "YES"]
    app.launch()
    XCTAssertTrue(
      app.buttons["Words of remembrance for morning and evening"].firstMatch.waitForExistence(
        timeout: 15))
    app.buttons["Words of remembrance for morning and evening"].firstMatch.tap()
    XCTAssertTrue(app.buttons["Slideshow"].waitForExistence(timeout: 5))
    app.buttons["Slideshow"].tap()

    let progress = app.staticTexts["slideshowProgress"]
    XCTAssertTrue(progress.waitForExistence(timeout: 5))
    XCTAssertEqual(progress.label, "1 of 24")
    XCTAssertFalse(app.buttons["slideshowCounter"].isHittable)

    let progressY = progress.frame.midY
    XCTAssertFalse(app.buttons["slideshowPrevious"].isEnabled)
    app.buttons["slideshowNext"].tap()
    XCTAssertTrue(progress.waitForExistence(timeout: 5))
    XCTAssertEqual(progress.label, "2 of 24")
    XCTAssertEqual(progress.frame.midY, progressY, accuracy: 1)
    XCTAssertTrue(app.buttons["slideshowPrevious"].isEnabled)
    app.buttons["slideshowPrevious"].tap()
    XCTAssertEqual(progress.label, "1 of 24")
    app.buttons["slideshowNext"].tap()
    let counter = app.buttons["slideshowCounter"]
    XCTAssertTrue(counter.waitForExistence(timeout: 5))
    XCTAssertLessThan(counter.frame.midX, app.frame.midX)
    XCTAssertLessThan(counter.frame.midY, app.frame.height / 3)
    counter.tap()
    XCTAssertTrue(app.scrollViews["counterZikrScroll"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Count: 3"].waitForExistence(timeout: 5))
    let image = XCTAttachment(screenshot: app.screenshot())
    image.name = "Slideshow counter sheet"
    image.lifetime = .keepAlways
    add(image)
  }

  @MainActor
  func testSlideshowHidesChromeForShortSets() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(en)", "-hasSeenIntro", "YES", "-hasPresentedPrayerLocationSetup", "YES"]
    app.launch()
    let search = app.searchFields.firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 15))
    search.tap()
    search.typeText("completing ablution")
    let category = app.buttons["What to say upon completing ablution"].firstMatch
    XCTAssertTrue(category.waitForExistence(timeout: 15))
    category.tap()
    XCTAssertTrue(app.buttons["Slideshow"].waitForExistence(timeout: 5))
    app.buttons["Slideshow"].tap()
    XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["slideshowProgress"].exists)
    XCTAssertTrue(app.buttons["slideshowNext"].exists)
    XCTAssertTrue(app.buttons["slideshowPrevious"].exists)
    XCTAssertFalse(app.otherElements["slideshowPagination"].exists)
    app.buttons["slideshowNext"].tap()
    app.buttons["slideshowNext"].tap()
    XCTAssertTrue(app.buttons["slideshowNext"].label.contains("Done"))
    XCTAssertTrue(app.buttons["Close"].exists, "The last slide stays open until Done.")
    app.buttons["slideshowNext"].tap()
    XCTAssertTrue(app.buttons["Slideshow"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["Close"].exists)
    XCTAssertFalse(app.keyboards.firstMatch.exists)
    let image = XCTAttachment(screenshot: app.screenshot())
    image.name = "Short slideshow without progress"
    image.lifetime = .keepAlways
    add(image)
  }

  @MainActor
  func testShortSlideshowKeepsCounterWithoutProgress() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(ar)", "-hasSeenIntro", "YES", "-hasPresentedPrayerLocationSetup", "YES"]
    app.launch()
    let search = app.searchFields.firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 15))
    search.tap()
    search.typeText("الرؤيا")
    let category = app.buttons["ما يفعل من رأى الرؤيا أو الحلم"].firstMatch
    XCTAssertTrue(category.waitForExistence(timeout: 15))
    category.tap()
    XCTAssertTrue(app.buttons["عرض الشرائح"].waitForExistence(timeout: 5))
    app.buttons["عرض الشرائح"].tap()
    XCTAssertTrue(app.buttons["slideshowCounter"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["slideshowProgress"].exists)
    app.buttons["slideshowCounter"].tap()
    XCTAssertTrue(app.scrollViews["counterZikrScroll"].waitForExistence(timeout: 5))
    let image = XCTAttachment(screenshot: app.screenshot())
    image.name = "Short slideshow keeps counter"
    image.lifetime = .keepAlways
    add(image)
  }

  @MainActor
  func testTwoSlidePaginationAndSingleSlideNavigation() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(en)", "-hasSeenIntro", "YES", "-hasPresentedPrayerLocationSetup", "YES"]
    app.launch()
    let search = app.searchFields.firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 15))
    search.tap()
    search.typeText("sitting between")
    let category = app.buttons["Invocations for sitting between two prostrations"].firstMatch
    XCTAssertTrue(category.waitForExistence(timeout: 5))
    category.tap()
    app.buttons["Slideshow"].tap()
    XCTAssertTrue(app.otherElements["slideshowPagination"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["slideshowProgress"].exists)
    app.buttons["slideshowNext"].tap()
    XCTAssertTrue(app.buttons["slideshowNext"].label.contains("Done"))
    app.buttons["slideshowPrevious"].tap()
    XCTAssertTrue(app.buttons["slideshowNext"].label.contains("Next"))
    app.buttons["Close"].tap()
    XCTAssertTrue(app.buttons["Slideshow"].waitForExistence(timeout: 5))
    if app.buttons["BackButton"].exists {
      app.buttons["BackButton"].tap()
    } else {
      app.navigationBars.buttons.firstMatch.tap()
    }
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    search.tap()
    if app.buttons["Clear text"].exists { app.buttons["Clear text"].tap() }
    search.typeText("undressing")
    let single = app.buttons["What to say when undressing"].firstMatch
    XCTAssertTrue(single.waitForExistence(timeout: 5))
    single.tap()
    app.buttons["Slideshow"].tap()
    XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["slideshowNext"].exists)
    XCTAssertFalse(app.buttons["slideshowPrevious"].exists)
    XCTAssertFalse(app.otherElements["slideshowPagination"].exists)
    XCTAssertTrue(app.buttons["slideshowDone"].exists)
    app.buttons["slideshowDone"].tap()
    XCTAssertTrue(app.buttons["Slideshow"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testAccentSelectionUpdatesSettings() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(ar)", "-hasSeenIntro", "YES", "-hasPresentedPrayerLocationSetup", "YES"]
    app.launch()
    app.buttons["القائمة"].tap()
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
  func testHomeCounterSheetAwardsPointsAndResetDoesNotAward() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(en)", "-hasSeenIntro", "YES", "-hasPresentedPrayerLocationSetup", "YES"]
    app.launch()
    let homePoints = app.buttons["journey-total-points"]
    XCTAssertTrue(homePoints.waitForExistence(timeout: 15))
    let initialPoints = try XCTUnwrap(Int(homePoints.value as? String ?? ""))
    app.buttons["Menu"].tap()
    app.buttons["Counter"].tap()
    let close = app.buttons["counter.close"]
    XCTAssertTrue(close.waitForExistence(timeout: 5))
    let counter = app.buttons["counter.count"]
    for _ in 0..<33 { counter.tap() }
    let points = app.descendants(matching: .any)["counter.points"].firstMatch
    XCTAssertEqual(points.value as? String, String(initialPoints + 1))
    app.buttons["Reset"].tap()
    XCTAssertEqual(counter.label, "Count: 0")
    XCTAssertEqual(points.value as? String, String(initialPoints + 1))
    close.tap()
    XCTAssertTrue(homePoints.waitForExistence(timeout: 5))
    XCTAssertEqual(homePoints.value as? String, String(initialPoints + 1))
  }

  @MainActor
  func testArabicMenuOpensCounter() throws {
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
