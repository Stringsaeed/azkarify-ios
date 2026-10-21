import XCTest

final class JourneyUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testNavigationLocationAndPointsDetailsInBothLanguages() {
    for language in ["en", "ar"] {
      let app = launch(language: language)
      // The prayer strip is a card on Today, below the greeting and the day's progress.
      let location = app.buttons["home.prayerLocation"]
      XCTAssertTrue(location.waitForExistence(timeout: 5))
      XCTAssertTrue(location.isHittable)
      let points = app.buttons["journey-total-points"]
      XCTAssertTrue(points.exists)
      // The points badge is the trailing toolbar item, so it mirrors in Arabic.
      if language == "ar" {
        XCTAssertLessThan(points.frame.midX, app.frame.midX)
      } else {
        XCTAssertGreaterThan(points.frame.midX, app.frame.midX)
      }
      points.tap()
      XCTAssertTrue(app.staticTexts["points.today"].waitForExistence(timeout: 5))
      attachScreenshot(app, name: "\(language) points details")
      app.buttons["points.dismiss"].tap()
      XCTAssertTrue(app.buttons["journey-morning"].waitForExistence(timeout: 5))
      let dailyProgress = app.descendants(matching: .any)["daily-progress"].firstMatch
      XCTAssertTrue(dailyProgress.exists)
      let percentage = dailyProgress.value as? String ?? ""
      XCTAssertTrue(percentage.contains("%") || percentage.contains("٪"))
      attachScreenshot(app, name: "\(language) today journeys")
      let fajr = app.buttons["journey-prayer-fajr"]
      reveal(fajr, in: app)
      let fajrValue = fajr.value as? String ?? ""
      XCTAssertTrue(fajrValue.contains("8") || fajrValue.contains("٨"), "Fajr has eight steps: \(fajrValue)")
      fajr.tap()
      XCTAssertTrue(app.buttons["journey-step-restroom"].waitForExistence(timeout: 5))
      attachScreenshot(app, name: "\(language) eight-step prayer journey")
      app.terminate()
    }
  }

  @MainActor
  func testPointsPersistAndRecheckingDoesNotAwardAgain() {
    let app = launch(language: "en")
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
    // Heading out has one step, so checking it finishes the journey.
    app.dismissCompletionSheetIfShown()
    app.terminate()
    app.launch()
    app.open(.today)
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
    XCTAssertFalse(
      app.buttons["completion.done"].waitForExistence(timeout: 3),
      "Re-completing a journey already rewarded today earns nothing, so no sheet")
    app.terminate()
    app.launch()
    app.open(.today)
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
    let morning = app.buttons["journey-morning"]
    reveal(morning, in: app)
    morning.tap()
    let wakeAzkar = app.buttons["journey-category-1"]
    XCTAssertTrue(wakeAzkar.waitForExistence(timeout: 5))
    attachScreenshot(app, name: "Morning journey timeline")
    wakeAzkar.tap()
    XCTAssertTrue(app.buttons["focusMode"].waitForExistence(timeout: 5))
    attachScreenshot(app, name: "Morning journey linked wake azkar")
    app.goBack()

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
    let app = XCUIApplication.launchConfigured(language: language)
    app.open(.today)
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
    attachScreenshot(app, name: "\(language) evening journey completion sheet")
    app.dismissCompletionSheetIfShown()
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
    app.open(.today)
    let evening = app.buttons["journey-evening"]
    reveal(evening, in: app)
    evening.tap()
  }

  @MainActor
  private func openArabicPrayerSettings(_ app: XCUIApplication) {
    app.open(.settings)
    let prayerTimes = app.buttons["مواقيت الصلاة"].firstMatch
    reveal(prayerTimes, in: app)
    prayerTimes.tap()
    XCTAssertTrue(app.textFields["prayer.locationName"].waitForExistence(timeout: 5))
  }

  @MainActor
  private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    app.reveal(element)
  }
}
