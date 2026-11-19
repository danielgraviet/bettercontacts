import Foundation

/// Structured facets for narrowing the contact list. Free-text search is
/// handled separately by `SearchEngine`, which understands natural language.
public struct ContactFilter: Equatable, Sendable {
    /// Contacts must carry at least one of these tags.
    public var tags: Set<String>
    /// Contacts whose location contains this text.
    public var location: String?
    public var onlyCloseCircle: Bool
    public var onlyWithBirthdays: Bool
    public var onlyWithPhoneNumbers: Bool
    /// When set, only contacts whose last logged interaction falls inside this
    /// interval are kept. Contacts with no logged interaction are excluded.
    public var lastInteractionWithin: DateInterval?

    public init(
        tags: Set<String> = [],
        location: String? = nil,
        onlyCloseCircle: Bool = false,
        onlyWithBirthdays: Bool = false,
        onlyWithPhoneNumbers: Bool = false,
        lastInteractionWithin: DateInterval? = nil
    ) {
        self.tags = tags
        self.location = location
        self.onlyCloseCircle = onlyCloseCircle
        self.onlyWithBirthdays = onlyWithBirthdays
        self.onlyWithPhoneNumbers = onlyWithPhoneNumbers
        self.lastInteractionWithin = lastInteractionWithin
    }

    public var isEmpty: Bool {
        tags.isEmpty
            && (location?.isEmpty ?? true)
            && !onlyCloseCircle
            && !onlyWithBirthdays
            && !onlyWithPhoneNumbers
            && lastInteractionWithin == nil
    }
}
