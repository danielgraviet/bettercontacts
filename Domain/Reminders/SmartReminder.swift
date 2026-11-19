import Foundation

/// One thing the app wants the user to do about one contact.
public struct SmartReminder: Equatable, Identifiable, Sendable {
    public enum Reason: Equatable, Hashable, Sendable {
        case upcomingBirthday(daysUntil: Int)
        case overdueTouchpoint(daysOverdue: Int)
    }

    public let contact: Contact
    public let reason: Reason

    public var id: String {
        switch reason {
        case .upcomingBirthday:
            return "\(contact.id)-birthday"
        case .overdueTouchpoint:
            return "\(contact.id)-touchpoint"
        }
    }

    public init(contact: Contact, reason: Reason) {
        self.contact = contact
        self.reason = reason
    }
}
