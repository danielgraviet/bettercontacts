import Domain
import Foundation

/// User-editable fields stored locally by BetterContacts.
struct ContactAnnotations {
    var tags: Set<String>
    var location: String?
    var notes: String
    var isCloseCircle: Bool

    func apply(to contact: inout Contact) {
        contact.tags = tags
        contact.location = location
        contact.notes = notes
        contact.isCloseCircle = isCloseCircle
    }
}

/// Address book records with local annotations, plus the persisted relationship history.
struct ContactSnapshot {
    let contacts: [Contact]
    let history: [String: [Interaction]]
    var snoozes: [String: Date] = [:]

    var hydratedContacts: [Contact] {
        contacts.map { sourceContact in
            var contact = sourceContact
            if let date = history[contact.id]?.first?.date {
                contact.lastInteractionDate = max(contact.lastInteractionDate ?? date, date)
            }
            return contact
        }
    }
}

enum ContactStorageError: LocalizedError {
    case missingTouchpoint
    case unsupported

    var errorDescription: String? {
        switch self {
        case .missingTouchpoint: return "This touchpoint could not be found."
        case .unsupported: return "This operation is unavailable."
        }
    }
}

/// The app’s address book and local relationship data.
@MainActor
protocol ContactRepositoryStoring {
    func allContacts() async throws -> [Contact]
    func loadSnapshot() async throws -> ContactSnapshot
    func interactions(for contactID: String) throws -> [Interaction]
    func record(interaction: Interaction) throws
    func update(interaction: Interaction) throws
    func remove(interaction: Interaction) throws
    func saveSnooze(until: Date?, for contactID: String) throws
    func saveAnnotations(_ annotations: ContactAnnotations, for contactID: String) throws
}

extension ContactRepositoryStoring {
    func loadSnapshot() async throws -> ContactSnapshot {
        let contacts = try await allContacts()
        let entries = try contacts.flatMap { try interactions(for: $0.id) }
        let history = Dictionary(grouping: entries.sorted { $0.date > $1.date }, by: \.contactID)
        return ContactSnapshot(contacts: contacts, history: history)
    }

    func update(interaction: Interaction) throws { throw ContactStorageError.unsupported }
    func remove(interaction: Interaction) throws { throw ContactStorageError.unsupported }
    func saveSnooze(until: Date?, for contactID: String) throws { throw ContactStorageError.unsupported }
}

@MainActor
final class ContactRepository: ContactRepositoryStoring {
    private let contactSource: ContactSourceProviding
    private let annotationStore: AnnotationStore

    init(contactSource: ContactSourceProviding, annotationStore: AnnotationStore) {
        self.contactSource = contactSource
        self.annotationStore = annotationStore
    }

    func allContacts() async throws -> [Contact] {
        try await loadSnapshot().hydratedContacts
    }

    func loadSnapshot() async throws -> ContactSnapshot {
        var contacts = try await contactSource.fetchAllContacts()
        let annotations = try annotationStore.allAnnotations()
        for index in contacts.indices {
            annotations[contacts[index].id]?.apply(to: &contacts[index])
        }
        let history = Dictionary(grouping: try annotationStore.interactionHistory(), by: \.contactID)
        return ContactSnapshot(contacts: contacts, history: history, snoozes: try annotationStore.snoozes())
    }

    func interactions(for contactID: String) throws -> [Interaction] {
        try annotationStore.interactions(for: contactID)
    }

    func record(interaction: Interaction) throws {
        try annotationStore.record(interaction: interaction)
    }

    func update(interaction: Interaction) throws {
        try annotationStore.update(interaction: interaction)
    }

    func remove(interaction: Interaction) throws {
        try annotationStore.remove(interaction: interaction)
    }

    func saveSnooze(until: Date?, for contactID: String) throws {
        try annotationStore.saveSnooze(until: until, for: contactID)
    }

    func saveAnnotations(_ annotations: ContactAnnotations, for contactID: String) throws {
        try annotationStore.upsertAnnotation(annotations, for: contactID)
    }
}
