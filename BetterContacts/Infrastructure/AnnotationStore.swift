import Domain
import Foundation
import SwiftData

/// SwiftData entity for everything BetterContacts layers on top of the system
/// address book for one contact: tags, location, notes, and close-circle
/// membership. Keyed by the CNContact identifier.
@Model
final class ContactAnnotationEntity {
    @Attribute(.unique) var contactID: String
    var tags: [String]
    var location: String?
    var notes: String
    var isCloseCircle: Bool

    init(
        contactID: String,
        tags: [String] = [],
        location: String? = nil,
        notes: String = "",
        isCloseCircle: Bool = false
    ) {
        self.contactID = contactID
        self.tags = tags
        self.location = location
        self.notes = notes
        self.isCloseCircle = isCloseCircle
    }
}

/// SwiftData entity for one logged touchpoint.
@Model
final class InteractionEntity {
    var id: UUID
    var contactID: String
    var date: Date
    var kind: String
    var note: String?

    init(id: UUID = UUID(), contactID: String, date: Date, kind: String, note: String? = nil) {
        self.id = id
        self.contactID = contactID
        self.date = date
        self.kind = kind
        self.note = note
    }
}

/// SwiftData-backed storage for annotations and the interaction log.
/// The domain never talks to SwiftData directly — only this class does.
@MainActor
final class AnnotationStore {
    private let context: ModelContext

    init(inMemory: Bool = false) {
        // A corrupted on-disk store must never take the app down: if the real
        // store fails to open, fall back to an in-memory one.
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        if let container = try? ModelContainer(
            for: ContactAnnotationEntity.self, InteractionEntity.self,
            configurations: configuration
        ) {
            context = ModelContext(container)
        } else {
            let fallbackConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
            guard let fallback = try? ModelContainer(
                for: ContactAnnotationEntity.self, InteractionEntity.self,
                configurations: fallbackConfiguration
            ) else {
                preconditionFailure("SwiftData in-memory store could not be created")
            }
            context = ModelContext(fallback)
        }
        context.autosaveEnabled = false
    }

    // MARK: Annotations

    func allAnnotations() throws -> [String: ContactAnnotationEntity] {
        let entities = try context.fetch(FetchDescriptor<ContactAnnotationEntity>())
        return Dictionary(entities.map { ($0.contactID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func upsertAnnotation(for contact: Contact) throws {
        let id = contact.id
        let existing = try context.fetch(
            FetchDescriptor<ContactAnnotationEntity>(predicate: #Predicate { $0.contactID == id })
        ).first
        if let existing {
            existing.tags = contact.tags.sorted()
            existing.location = contact.location
            existing.notes = contact.notes
            existing.isCloseCircle = contact.isCloseCircle
        } else {
            context.insert(ContactAnnotationEntity(
                contactID: contact.id,
                tags: contact.tags.sorted(),
                location: contact.location,
                notes: contact.notes,
                isCloseCircle: contact.isCloseCircle
            ))
        }
        try context.save()
    }

    // MARK: Interactions

    func record(interaction: Interaction) throws {
        context.insert(InteractionEntity(
            id: interaction.id,
            contactID: interaction.contactID,
            date: interaction.date,
            kind: interaction.kind.rawValue,
            note: interaction.note
        ))
        try context.save()
    }

    func interactions(for contactID: String) throws -> [Interaction] {
        let descriptor = FetchDescriptor<InteractionEntity>(
            predicate: #Predicate { $0.contactID == contactID },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let entities = try context.fetch(descriptor)
        return entities.map { entity in
            Interaction(
                id: entity.id,
                contactID: entity.contactID,
                date: entity.date,
                kind: InteractionKind(rawValue: entity.kind) ?? .note,
                note: entity.note
            )
        }
    }

    /// The most recent interaction date per contact, computed in one pass.
    func latestInteractionDates() throws -> [String: Date] {
        let entities = try context.fetch(FetchDescriptor<InteractionEntity>())
        var latest: [String: Date] = [:]
        for entity in entities {
            if let current = latest[entity.contactID] {
                if entity.date > current {
                    latest[entity.contactID] = entity.date
                }
            } else {
                latest[entity.contactID] = entity.date
            }
        }
        return latest
    }
}
