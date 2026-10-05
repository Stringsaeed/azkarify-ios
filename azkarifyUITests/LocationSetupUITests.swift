import XCTest

final class LocationSetupUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor
  func testLocationSheetClosesFromTopLeft() {
    let app = launchUnconfiguredHome(language: "ar")
    let close = app.buttons["location.close"]
    XCTAssertTrue(close.waitForExistence(timeout: 5))
    XCTAssertLessThan(close.frame.midX, app.frame.midX)
    XCTAssertFalse(app.buttons["location.notNow"].exists)
    close.tap()
    XCTAssertFalse(app.buttons["location.useDevice"].exists)
    XCTAssertTrue(app.buttons["home.prayerLocation"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testDeniedLocationOffersCityAndRemembersSelection() {
    let app = launchUnconfiguredHome()
    app.buttons["location.useDevice"].tap()
    let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 10))
    let deny = alert.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Don")).firstMatch
    XCTAssertTrue(deny.exists)
    deny.tap()
    let dubai = app.buttons["location.city.Dubai"]
    XCTAssertTrue(dubai.waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Settings")).firstMatch.isHittable)
    screenshot(app, "City fallback after denying location")
    dubai.tap()
    let location = app.buttons["home.prayerLocation"]
    XCTAssertTrue(location.waitForExistence(timeout: 5))
    XCTAssertTrue(location.label.contains("Dubai"))
    app.terminate()
    app.launchArguments = baseArguments
    app.launch()
    XCTAssertTrue(location.waitForExistence(timeout: 10))
    XCTAssertTrue(location.label.contains("Dubai"))
    XCTAssertFalse(app.buttons["location.useDevice"].exists)
  }

  @MainActor
  func testAllowedLocationSavesCoordinatesOnDevice() {
    let app = launchUnconfiguredHome()
    app.buttons["location.useDevice"].tap()
    let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 10))
    let allow = alert.buttons["Allow Once"]
    XCTAssertTrue(allow.exists)
    allow.tap()
    let homeLocation = app.buttons["home.prayerLocation"]
    let sheetGone = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"), object: app.buttons["location.useDevice"])
    XCTAssertEqual(XCTWaiter.wait(for: [sheetGone], timeout: 20), .completed)
    XCTAssertTrue(homeLocation.label.contains("Current location"))
    app.buttons["Menu"].tap()
    app.buttons["Settings"].tap()
    app.buttons["Prayer times"].firstMatch.tap()
    XCTAssertTrue(app.textFields["prayer.locationName"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.textFields["prayer.locationName"].value as? String, "Current location")
    let coordinates = app.textFields.allElementsBoundByIndex.compactMap { $0.value as? String }
    XCTAssertTrue(coordinates.contains("25.2048"))
    XCTAssertTrue(coordinates.contains("55.2708"))
    screenshot(app, "Prayer settings from device location")
  }

  @MainActor
  func testArabicCityChoiceWithoutLocationPermission() {
    let app = launchUnconfiguredHome(language: "ar")
    app.buttons["location.chooseCity"].tap()
    let country = app.buttons["location.country"]
    XCTAssertTrue(country.waitForExistence(timeout: 5))
    XCTAssertTrue((country.label + " " + (country.value as? String ?? "")).contains("الإمارات"))
    country.tap()
    let countrySearch = app.searchFields.firstMatch
    XCTAssertTrue(countrySearch.waitForExistence(timeout: 5))
    countrySearch.tap()
    countrySearch.typeText("Egypt")
    app.buttons["country.EG"].tap()
    let search = app.textFields["location.search"]
    search.tap()
    search.typeText("Cairo")
    let cairo = app.buttons["location.city.Cairo"]
    XCTAssertTrue(cairo.waitForExistence(timeout: 5))
    XCTAssertFalse(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.exists)
    screenshot(app, "Arabic manual city selection")
    cairo.tap()
    let location = app.buttons["home.prayerLocation"]
    XCTAssertTrue(location.waitForExistence(timeout: 5))
    XCTAssertTrue(location.label.contains("القاهرة"))
  }

  @MainActor
  func testLocationSheetFitsContentAndCitySearchStaysInCountry() {
    let app = launchUnconfiguredHome()
    let sheet = app.descendants(matching: .any)["prayerLocationSheet"].firstMatch
    XCTAssertTrue(sheet.exists)
    XCTAssertLessThan(sheet.frame.height, app.frame.height * 0.7)
    app.buttons["location.chooseCity"].tap()
    let back = app.buttons["location.back"]
    XCTAssertTrue(back.waitForExistence(timeout: 5))
    back.tap()
    XCTAssertTrue(app.buttons["location.useDevice"].waitForExistence(timeout: 5))
    app.buttons["location.chooseCity"].tap()
    let citySearch = app.textFields["location.search"]
    citySearch.tap()
    citySearch.typeText("Cairo")
    XCTAssertFalse(app.buttons["location.city.Cairo"].exists)
    app.buttons["location.country"].tap()
    let countrySearch = app.searchFields.firstMatch
    XCTAssertTrue(countrySearch.waitForExistence(timeout: 5))
    countrySearch.tap()
    countrySearch.typeText("Egypt")
    screenshot(app, "Searchable country sheet")
    app.buttons["country.EG"].tap()
    XCTAssertTrue(app.buttons["location.city.Cairo"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["location.city.Dubai"].exists)
    screenshot(app, "Cities scoped to Egypt")
  }

  private var baseArguments: [String] {
    ["-AppleLanguages", "(en)", "-AppleLocale", "en_AE", "-hasSeenIntro", "YES", "-hasPresentedPrayerLocationSetup", "NO"]
  }

  @MainActor
  private func launchUnconfiguredHome(language: String = "en") -> XCUIApplication {
    let app = XCUIApplication()
    app.resetAuthorizationStatus(for: .location)
    // Shadow a previous simulator configuration without deleting other app data.
    app.launchArguments = baseArguments + ["-prayerSchedule.configuration.v1", ""]
    app.launchArguments[1] = "(\(language))"
    app.launch()
    XCTAssertTrue(app.buttons["location.useDevice"].waitForExistence(timeout: 15))
    screenshot(app, "Home location setup \(language)")
    return app
  }

  @MainActor
  private func screenshot(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
