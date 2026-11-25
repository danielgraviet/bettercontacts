import Foundation

/// A person in the user's address book, expressed in BetterContacts' own terms.
///
/// Deliberately decoupled from `CNContact` so that all domain logic
/// (filtering, sorting, reminders, and search) is pure and trivially testable.
public struct Contact: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: String
    public var firstName: String
    public var lastName: String
    public var organization: String?
    public var phoneNumbers: [String]
    public var emailAddresses: [String]
    /// The annually recurring birthday, when known. No year.
    public var birthday: MonthDay?
    /// A free-form place tag, e.g. "Berlin".
    public var location: String?
    public var notes: String
    public var tags: Set<String>
    public var isCloseCircle: Bool
    /// When the contact entered BetterContacts. Touchpoint staleness is
    /// measured from this date until the first interaction is logged.
    public let createdAt: Date
    /// Date of the most recent logged interaction, if any.
    public var lastInteractionDate: Date?

    public init(
        id: String,
        firstName: String,
        lastName: String,
        organization: String? = nil,
        phoneNumbers: [String] = [],
        emailAddresses: [String] = [],
        birthday: MonthDay? = nil,
        location: String? = nil,
        notes: String = "",
        tags: Set<String> = [],
        isCloseCircle: Bool = false,
        createdAt: Date = Date(),
        lastInteractionDate: Date? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.organization = organization
        self.phoneNumbers = phoneNumbers
        self.emailAddresses = emailAddresses
        self.birthday = birthday
        self.location = location
        self.notes = notes
        self.tags = tags
        self.isCloseCircle = isCloseCircle
        self.createdAt = createdAt
        self.lastInteractionDate = lastInteractionDate
    }

    /// The name shown to the user: first then last, falling back to the
    /// organization when no name parts exist.
    public var displayName: String {
        let name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            return name
        }
        if let organization, !organization.isEmpty {
            return organization
        }
        return "Unknown"
    }

    /// Everything about a contact that free-text search should be able to reach.
    public var searchableText: String {
        [
            displayName,
            organization ?? "",
            location ?? "",
            tags.sorted().joined(separator: " "),
            notes
        ]
        .joined(separator: " ")
    }
}
