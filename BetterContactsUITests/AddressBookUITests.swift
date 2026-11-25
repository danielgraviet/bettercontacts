import XCTest

final class AddressBookUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAddsAContactToTheAddressBook() {
        // Given the sample address book is open
        let app = launchAddressBook()

        // When saving a new contact
        app.buttons["Add Contact"].tap()
        app.textFields["First Name"].tap()
        app.textFields["First Name"].typeText("Katherine")
        app.buttons["Save Contact"].tap()

        // Then the person appears in the contact list
        XCTAssertTrue(app.staticTexts["Katherine"].waitForExistence(timeout: 5))
    }

    func testEditsAContactName() {
        // Given Ada’s contact is open
        let app = launchAddressBook()
        app.staticTexts["Ada Lovelace"].tap()

        // When changing part of her name
        app.buttons["Contact Actions"].tap()
        app.buttons["Edit Contact"].tap()
        app.textFields["Last Name"].tap()
        app.textFields["Last Name"].typeText(" Byron")
        app.buttons["Save Contact"].tap()

        // Then the contact detail shows her updated name
        XCTAssertTrue(app.navigationBars["Ada Lovelace Byron"].waitForExistence(timeout: 5))
    }

    func testDeletesAContactAfterConfirmation() {
        // Given Alan’s contact is open
        let app = launchAddressBook()
        app.staticTexts["Alan Turing"].tap()

        // When confirming deletion
        app.buttons["Contact Actions"].tap()
        app.buttons["Delete Contact"].tap()
        app.alerts.buttons["Delete Contact"].tap()

        // Then the address book returns without Alan
        XCTAssertTrue(app.staticTexts["Ada Lovelace"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Alan Turing"].exists)
    }

    private func launchAddressBook() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-sample-contacts"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Ada Lovelace"].waitForExistence(timeout: 15))
        return app
    }
}
