import Domain
import Foundation

/// The seam between the app and the system address book. UI tests and preview
/// fixtures swap in sample data through this protocol.
@MainActor
protocol ContactSourceProviding {
    func fetchAllContacts() async throws -> [Contact]
}
