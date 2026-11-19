import SwiftUI

@main
struct BetterContactsApp: App {
    private let environment: AppEnvironment

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment
        if arguments.contains("-uitest-sample-contacts") {
            // UI tests launch with -uitest-sample-contacts, so they never
            // touch the real address book or wait on permission dialogs.
            self.environment = AppEnvironment.uiTestSample()
        } else if environment["XCTestConfigurationFilePath"] != nil {
            // Hosted unit tests launch the app too; keep them hermetic and
            // permission-free with the same in-memory sample data.
            self.environment = AppEnvironment.uiTestSample()
        } else {
            self.environment = AppEnvironment.live()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
        }
    }
}
