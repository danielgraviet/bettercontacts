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

@Model
final class ReminderSnoozeEntity {
    @Attribute(.unique) var contactID: String
    var until: Date

    init(contactID: String, until: Date) {
        self.contactID = contactID
        self.until = until
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
            for: ContactAnnotationEntity.self, InteractionEntity.self, ReminderSnoozeEntity.self,
            configurations: configuration
        ) {
            context = ModelContext(container)
        } else {
            let fallbackConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
            guard let fallback = try? ModelContainer(
                for: ContactAnnotationEntity.self, InteractionEntity.self, ReminderSnoozeEntity.self,
                configurations: fallbackConfiguration
            ) else {
                preconditionFailure("SwiftData in-memory store could not be created")
            }
            context = ModelContext(fallback)
        }
        context.autosaveEnabled = false
    }

    // MARK: Annotations

    func allAnnotations() throws -> [String: ContactAnnotations] {
        let entities = try context.fetch(FetchDescriptor<ContactAnnotationEntity>())
        return Dictionary(uniqueKeysWithValues: entities.map { entity in
            (entity.contactID, ContactAnnotations(
                tags: Set(entity.tags),
                location: entity.location,
                notes: entity.notes,
                isCloseCircle: entity.isCloseCircle
            ))
        })
    }

    func upsertAnnotation(_ annotations: ContactAnnotations, for contactID: String) throws {
        let existing = try context.fetch(
            FetchDescriptor<ContactAnnotationEntity>(predicate: #Predicate { $0.contactID == contactID })
        ).first
        let entity = existing ?? ContactAnnotationEntity(contactID: contactID)
        entity.tags = annotations.tags.sorted()
        entity.location = annotations.location
        entity.notes = annotations.notes
        entity.isCloseCircle = annotations.isCloseCircle
        if existing == nil {
            context.insert(entity)
        }
        try save()
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
        try save()
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func update(interaction: Interaction) throws {
        guard let entity = try interactionEntity(for: interaction) else { throw ContactStorageError.missingTouchpoint }
        entity.date = interaction.date
        entity.kind = interaction.kind.rawValue
        entity.note = interaction.note
        try save()
    }

    func remove(interaction: Interaction) throws {
        guard let entity = try interactionEntity(for: interaction) else { return }
        context.delete(entity)
        try save()
    }

    private func interactionEntity(for interaction: Interaction) throws -> InteractionEntity? {
        let id = interaction.id
        let contactID = interaction.contactID
        var descriptor = FetchDescriptor<InteractionEntity>(
            predicate: #Predicate { $0.id == id && $0.contactID == contactID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func interactions(for contactID: String) throws -> [Interaction] {
        try fetchInteractions(matching: #Predicate { $0.contactID == contactID })
    }

    func interactionHistory() throws -> [Interaction] {
        try fetchInteractions(matching: nil)
    }

    private func fetchInteractions(matching predicate: Predicate<InteractionEntity>?) throws -> [Interaction] {
        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\InteractionEntity.date, order: .reverse)]
        )
        return try context.fetch(descriptor).map { entity in
            Interaction(
                id: entity.id,
                contactID: entity.contactID,
                date: entity.date,
                kind: InteractionKind(rawValue: entity.kind) ?? .note,
                note: entity.note
            )
        }
    }

    func snoozes() throws -> [String: Date] {
        let entities = try context.fetch(FetchDescriptor<ReminderSnoozeEntity>())
        return Dictionary(uniqueKeysWithValues: entities.map { ($0.contactID, $0.until) })
    }

    func saveSnooze(until: Date?, for contactID: String) throws {
        let descriptor = FetchDescriptor<ReminderSnoozeEntity>(predicate: #Predicate { $0.contactID == contactID })
        let existing = try context.fetch(descriptor).first
        switch (existing, until) {
        case let (entity?, date?): entity.until = date
        case let (nil, date?): context.insert(ReminderSnoozeEntity(contactID: contactID, until: date))
        case let (entity?, nil): context.delete(entity)
        case (nil, nil): return
        }
        try save()
    }
}
