import Foundation

/// The orderings the contact list offers.
public enum ContactSort: String, CaseIterable, Identifiable, Sendable {
    case alphabetical
    case soonestBirthday
    case mostRecentlyInteracted
    case mostStaleRelationship

    public var id: String { rawValue }
}
