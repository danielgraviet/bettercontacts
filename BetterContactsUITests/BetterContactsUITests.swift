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
}
