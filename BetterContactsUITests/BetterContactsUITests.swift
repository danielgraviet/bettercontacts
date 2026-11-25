import XCTest

final class BetterContactsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesAndShowsSampleContacts() {
        // The app is launched in sample-contacts mode, so this smoke test
        // never depends on the simulator's address book or a permission dialog.
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-sample-contacts"]
        app.launch()

        let ada = app.staticTexts["Ada Lovelace"]
        XCTAssertTrue(
            ada.waitForExistence(timeout: 15),
            "The sample contact Ada Lovelace should be visible after launch."
        )
    }

    func testLoggedTouchpointAppearsInContactHistory() {
        // Given a contact opened from the sample address book
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-sample-contacts"]
        app.launch()
        let ada = app.staticTexts["Ada Lovelace"]
        XCTAssertTrue(ada.waitForExistence(timeout: 15))
        ada.tap()

        // When the user logs an in-person meeting
        app.buttons["Log an interaction"].tap()
        app.buttons["Met in person"].tap()

        // Then the meeting appears in the contact’s history
        XCTAssertTrue(app.staticTexts["Met in person"].waitForExistence(timeout: 5))
    }
}

final class MVPWorkflowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLogsATouchpointWithADateAndNote() {
        // Given Ada’s contact details are open
        let app = openAda()

        // When logging yesterday’s meeting with a note
        app.buttons["Log an interaction"].tap()
        app.buttons["Choose date and note"].tap()
        app.buttons["Yesterday"].tap()
        app.textFields["Touchpoint note"].tap()
        app.textFields["Touchpoint note"].typeText("Coffee at the station")
        app.buttons["Save Touchpoint"].tap()

        // Then the history shows the note and yesterday’s date
        XCTAssertTrue(app.staticTexts["Coffee at the station"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Yesterday"].exists)
    }

    func testEditsAnExistingTouchpoint() {
        // Given a meeting has been logged on Ada’s contact
        let app = openAda()
        app.buttons["Log an interaction"].tap()
        app.buttons["Met in person"].tap()

        // When editing the meeting to add context
        app.buttons["Edit Met in person touchpoint"].tap()
        app.textFields["Touchpoint note"].tap()
        app.textFields["Touchpoint note"].typeText("Discussed the book")
        app.buttons["Save Touchpoint"].tap()

        // Then the updated note appears on the single existing entry
        XCTAssertTrue(app.staticTexts["Discussed the book"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(identifier: "Met in person").count, 1)
    }

    func testUndoesANewTouchpoint() {
        // Given a meeting has just been logged on Ada’s contact
        let app = openAda()
        app.buttons["Log an interaction"].tap()
        app.buttons["Met in person"].tap()

        // When undoing the log
        app.buttons["Undo Touchpoint"].tap()

        // Then the history is empty
        XCTAssertTrue(app.staticTexts["Nothing logged yet."].waitForExistence(timeout: 5))
    }

    func testSnoozesACatchUpReminder() {
        // Given Ada is due for a catch-up
        let app = openReminders()
        let ada = app.staticTexts["Ada Lovelace"]
        XCTAssertTrue(ada.waitForExistence(timeout: 5))

        // When snoozing her reminder for a week
        app.buttons["Actions for Ada Lovelace"].tap()
        app.buttons["Snooze for 1 Week"].tap()

        // Then Ada is no longer due for a catch-up
        XCTAssertTrue(app.staticTexts["Everyone is up to date."].waitForExistence(timeout: 5))
    }

    func testLogsATouchpointFromAReminder() {
        // Given Ada is due for a catch-up
        let app = openReminders()
        XCTAssertTrue(app.staticTexts["Ada Lovelace"].waitForExistence(timeout: 5))

        // When logging a touchpoint directly from the reminder
        app.buttons["Actions for Ada Lovelace"].tap()
        app.buttons["Log Touchpoint"].tap()
        app.buttons["Save Touchpoint"].tap()

        // Then Ada is no longer due for a catch-up
        XCTAssertTrue(app.staticTexts["Everyone is up to date."].waitForExistence(timeout: 5))
    }

    private func openAda() -> XCUIApplication {
        let app = launchSampleApp()
        app.staticTexts["Ada Lovelace"].tap()
        return app
    }

    private func openReminders() -> XCUIApplication {
        let app = launchSampleApp()
        app.buttons["Reminders"].tap()
        return app
    }

    private func launchSampleApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-sample-contacts"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Ada Lovelace"].waitForExistence(timeout: 15))
        return app
    }
}
