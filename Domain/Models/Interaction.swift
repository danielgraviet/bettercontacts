import Foundation

/// How a touchpoint was kept.
public enum InteractionKind: String, Codable, CaseIterable, Sendable {
    case call
    case message
    case metInPerson
    case email
    case note

    public var displayName: String {
        switch self {
        case .call: return "Call"
        case .message: return "Message"
        case .metInPerson: return "Met in person"
        case .email: return "Email"
        case .note: return "Note"
        }
    }
}

/// A single logged touchpoint with a contact — a call, a coffee, a quick text.
public struct Interaction: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let contactID: String
    public let date: Date
    public let kind: InteractionKind
    public var note: String?

    public init(
        id: UUID = UUID(),
        contactID: String,
        date: Date,
        kind: InteractionKind,
        note: String? = nil
    ) {
        self.id = id
        self.contactID = contactID
        self.date = date
        self.kind = kind
        self.note = note
    }
}
