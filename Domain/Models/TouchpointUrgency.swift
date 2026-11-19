import Foundation

/// How overdue a relationship is — the core signal for "who should I reach out to?".
public struct TouchpointUrgency: Equatable, Identifiable, Sendable {
    public let contact: Contact
    /// Whole days since the last interaction (or since the contact was added,
    /// if no interaction has been logged yet).
    public let daysSinceLastInteraction: Int
    /// The cadence this contact is held to.
    public let cadenceDays: Int

    public var id: String { contact.id }

    /// A contact is due exactly on the day its cadence elapses, not the day after.
    public var isDue: Bool { daysSinceLastInteraction >= cadenceDays }

    /// Days past the cadence. Never negative.
    public var daysOverdue: Int { max(0, daysSinceLastInteraction - cadenceDays) }

    public init(contact: Contact, daysSinceLastInteraction: Int, cadenceDays: Int) {
        self.contact = contact
        self.daysSinceLastInteraction = daysSinceLastInteraction
        self.cadenceDays = cadenceDays
    }
}
