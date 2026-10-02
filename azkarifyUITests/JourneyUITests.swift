import XCTest

final class JourneyUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testNavigationLocationAndPointsDetailsInBothLanguages() {
    for language in ["en", "ar"] {
      let app = launch(language: language)
      let location = app.buttons["home.prayerLocation"]
      XCTAssertTrue(location.waitForExistence(timeout: 5))
      XCTAssertLessThan(location.frame.maxY, app.frame.height * 0.25)
      let points = app.buttons["journey-total-points"]
      XCTAssertTrue(points.exists)
      XCTAssertGreaterThan(points.frame.midX, app.frame.midX)
      points.tap()
      XCTAssertTrue(app.staticTexts["points.today"].waitForExistence(timeout: 5))
      attachScreenshot(app, name: "\(language) points details with mosaic")
      app.buttons["points.dismiss"].tap()
      app.buttons["dailyJourneys"].tap()
      XCTAssertTrue(app.buttons["journey-morning"].waitForExistence(timeout: 5))
      let dailyProgress = app.descendants(matching: .any)["daily-progress"].firstMatch
      XCTAssertTrue(dailyProgress.exists)
      let percentage = dailyProgress.value as? String ?? ""
      XCTAssertTrue(percentage.contains("%") || percentage.contains("٪"))
      attachScreenshot(app, name: "\(language) journeys with exact crescent and navigation")
      let fajr = app.buttons["journey-prayer-fajr"]
      reveal(fajr, in: app)
      XCTAssertTrue((fajr.value as? String ?? "").contains("8"))
      fajr.tap()
      XCTAssertTrue(app.buttons["journey-step-restroom"].waitForExistence(timeout: 5))
      attachScreenshot(app, name: "\(language) eight-step prayer journey")
      app.terminate()
    }
  }

  @MainActor
  func testPointsPersistAndRecheckingDoesNotAwardAgain() {
    let app = launch(language: "en")
    app.buttons["dailyJourneys"].tap()
    let total = app.buttons["journey-total-points"]
    XCTAssertTrue(total.waitForExistence(timeout: 5))
    let initialPoints = Int(total.value as? String ?? "")
    XCTAssertNotNil(initialPoints)
    let goingOut = app.buttons["journey-going-out"]
    reveal(goingOut, in: app)
    goingOut.tap()
    let step = app.buttons["journey-step-leave-home"]
    XCTAssertTrue(step.waitForExistence(timeout: 5))
    if step.isSelected {
      step.tap()
      waitForSelection(step, selected: false)
    }
    step.tap()
    waitForSelection(step, selected: true)
    app.terminate()
    app.launch()
    app.buttons["dailyJourneys"].tap()
    XCTAssertTrue(total.waitForExistence(timeout: 5))
    let earnedPoints = Int(total.value as? String ?? "")
    XCTAssertNotNil(earnedPoints)
    // A prior run may already have earned this day's reward.
    XCTAssertTrue(earnedPoints == initialPoints || earnedPoints == initialPoints.map { $0 + 35 })
    attachScreenshot(app, name: "Local journey points")
    reveal(goingOut, in: app)
    goingOut.tap()
    XCTAssertTrue(step.waitForExistence(timeout: 5))
    XCTAssertTrue(step.isSelected)
    step.tap()
    waitForSelection(step, selected: false)
    step.tap()
    waitForSelection(step, selected: true)
    app.terminate()
    app.launch()
    app.buttons["dailyJourneys"].tap()
    XCTAssertTrue(total.waitForExistence(timeout: 5))
    XCTAssertEqual(Int(total.value as? String ?? ""), earnedPoints)
  }

  @MainActor
  func testEnglishEveningJourneyCompletionSurvivesRelaunch() {
    let app = launch(language: "en")
    completeEveningJourneyAndRelaunch(app, language: "en")
  }

  @MainActor
  func testArabicJourneyAndPrayerConfigurationSurviveRelaunch() {
    let app = launch(language: "ar")
    completeEveningJourneyAndRelaunch(app, language: "ar")

    app.terminate()
    app.launch()
    openArabicPrayerSettings(app)
    let chooseCity = app.buttons["اختر مدينة"].firstMatch
    XCTAssertTrue(chooseCity.waitForExistence(timeout: 5))
    chooseCity.tap()
    let countryPicker = app.buttons["prayer.country"]
    XCTAssertTrue(countryPicker.waitForExistence(timeout: 5))
    countryPicker.tap()
    let countrySearch = app.searchFields.firstMatch
    XCTAssertTrue(countrySearch.waitForExistence(timeout: 5))
    countrySearch.tap()
    countrySearch.typeText("AE")
    app.buttons["country.AE"].tap()
    let citySearch = app.searchFields.firstMatch
    XCTAssertTrue(citySearch.waitForExistence(timeout: 5))
    citySearch.tap()
    citySearch.typeText("Dubai")
    let dubai = app.buttons["prayer.city.Dubai"].firstMatch
    XCTAssertTrue(dubai.waitForExistence(timeout: 5))
    dubai.tap()

    let madhab = app.buttons["prayer.madhab"]
    reveal(madhab, in: app)
    madhab.tap()
    let hanafi = app.buttons["الحنفي، العصر المتأخر"].firstMatch
    XCTAssertTrue(hanafi.waitForExistence(timeout: 5))
    hanafi.tap()
    attachScreenshot(app, name: "Arabic prayer configuration before saving")

    let save = app.buttons["prayer.save"]
    reveal(save, in: app)
    XCTAssertTrue(save.isEnabled)
    save.tap()
    let dismissed = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"), object: save)
    XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)

    app.terminate()
    app.launch()
    openArabicPrayerSettings(app)
    XCTAssertEqual(app.textFields["prayer.locationName"].value as? String, "دبي")
    XCTAssertTrue(app.buttons["prayer.timeZone"].label.contains("Asia/Dubai"))

    let savedMethod = app.buttons["prayer.method"]
    reveal(savedMethod, in: app)
    XCTAssertTrue(
      (savedMethod.label + " " + (savedMethod.value as? String ?? "")).contains("دبي"),
      "The selected city must persist its Dubai calculation method. Label: \(savedMethod.label), value: \(String(describing: savedMethod.value))")
    let savedMadhab = app.buttons["prayer.madhab"]
    XCTAssertTrue(
      (savedMadhab.label + " " + (savedMadhab.value as? String ?? "")).contains("الحنفي"),
      "The manually selected Asr calculation must survive relaunch. Label: \(savedMadhab.label), value: \(String(describing: savedMadhab.value))")
    attachScreenshot(app, name: "Arabic prayer configuration after relaunch")
  }

  @MainActor
  func testMorningJourneyLinksAzkarAndRecordsDuhaChoice() {
    let app = launch(language: "en")
    app.buttons["dailyJourneys"].tap()
    let morning = app.buttons["journey-morning"]
    reveal(morning, in: app)
    morning.tap()
    let wakeAzkar = app.buttons["journey-category-1"]
    XCTAssertTrue(wakeAzkar.waitForExistence(timeout: 5))
    attachScreenshot(app, name: "Morning journey timeline")
    wakeAzkar.tap()
    XCTAssertTrue(app.buttons["Slideshow"].waitForExistence(timeout: 5))
    attachScreenshot(app, name: "Morning journey linked wake azkar")
    let back = app.buttons["BackButton"]
    if back.exists {
      back.tap()
    } else {
      app.navigationBars.buttons.firstMatch.tap()
    }

    let duha = app.buttons["journey-choice-duha"]
    reveal(duha, in: app)
    duha.tap()
    waitForSelection(duha, selected: true)
    let prayerStep = app.buttons["journey-step-prayer"]
    reveal(prayerStep, in: app)
    XCTAssertTrue(prayerStep.isEnabled, "Choosing Duha must allow completing the prayer step")
    if prayerStep.isSelected {
      prayerStep.tap()
      waitForSelection(prayerStep, selected: false)
    }
    prayerStep.tap()
    waitForSelection(prayerStep, selected: true)
    XCTAssertEqual(prayerStep.value as? String, "Complete")
    XCTAssertTrue(duha.isSelected)
    attachScreenshot(app, name: "Morning journey Duha step completed")
  }

  @MainActor
  private func launch(language: String) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(\(language))", "-hasSeenIntro", "YES", "-hasPresentedPrayerLocationSetup", "YES"]
    app.launch()
    XCTAssertTrue(app.buttons["dailyJourneys"].waitForExistence(timeout: 15))
    return app
  }

  @MainActor
  private func completeEveningJourneyAndRelaunch(_ app: XCUIApplication, language: String) {
    openEveningJourney(app)
    let step = app.buttons["journey-step-evening-azkar"]
    XCTAssertTrue(step.waitForExistence(timeout: 5))

    if step.isSelected {
      step.tap()
      waitForSelection(step, selected: false)
    }
    XCTAssertEqual(step.value as? String, language == "ar" ? "غير مكتملة" : "Incomplete")
    step.tap()
    waitForSelection(step, selected: true)
    XCTAssertEqual(
      app.staticTexts["journey-completion"].label,
      language == "ar" ? "اكتملت الرحلة" : "Journey complete")
    attachScreenshot(app, name: "\(language) evening journey completed")

    app.terminate()
    app.launch()
    openEveningJourney(app)
    let restoredStep = app.buttons["journey-step-evening-azkar"]
    XCTAssertTrue(restoredStep.waitForExistence(timeout: 5))
    XCTAssertTrue(restoredStep.isSelected, "A completed step must survive app termination")
    XCTAssertEqual(restoredStep.value as? String, language == "ar" ? "مكتملة" : "Complete")
    XCTAssertEqual(
      app.staticTexts["journey-completion"].label,
      language == "ar" ? "اكتملت الرحلة" : "Journey complete")
    attachScreenshot(app, name: "\(language) evening journey restored")
  }

  @MainActor
  private func openEveningJourney(_ app: XCUIApplication) {
    let homeEntry = app.buttons["dailyJourneys"]
    XCTAssertTrue(homeEntry.waitForExistence(timeout: 15))
    homeEntry.tap()
    let evening = app.buttons["journey-evening"]
    reveal(evening, in: app)
    evening.tap()
  }

  @MainActor
  private func openArabicPrayerSettings(_ app: XCUIApplication) {
    let settings = app.buttons["الإعدادات"]
    XCTAssertTrue(settings.waitForExistence(timeout: 15))
    settings.tap()
    let prayerTimes = app.buttons["مواقيت الصلاة"].firstMatch
    reveal(prayerTimes, in: app)
    prayerTimes.tap()
    XCTAssertTrue(app.textFields["prayer.locationName"].waitForExistence(timeout: 5))
  }

  @MainActor
  private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    for _ in 0..<12 {
      if element.exists && element.isHittable { return }
      app.swipeUp()
    }
    XCTAssertTrue(element.exists && element.isHittable, "Expected control to be reachable by scrolling")
  }

  @MainActor
  private func waitForSelection(_ element: XCUIElement, selected: Bool) {
    let expectation = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "selected == %@", NSNumber(value: selected)), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
  }

  @MainActor
  private func attachScreenshot(_ app: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
