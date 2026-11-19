import Domain
import Foundation

/// Everything the app knows about a contact, in one place: the system address
/// book entry, joined with BetterContacts' own annotations and interaction log.
@MainActor
protocol ContactRepositoryStoring {
    func allContacts() async throws -> [Contact]
    func interactions(for contactID: String) throws -> [Interaction]
    func record(interaction: Interaction) throws
    func saveChanges(for contact: Contact) throws
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
        var contacts = try await contactSource.fetchAllContacts()
        let annotations = try annotationStore.allAnnotations()
        let latestInteractions = try annotationStore.latestInteractionDates()
        for index in contacts.indices {
            hydrate(
                &contacts[index],
                annotation: annotations[contacts[index].id],
                latestInteractionDate: latestInteractions[contacts[index].id]
            )
        }
        return contacts
    }

    func interactions(for contactID: String) throws -> [Interaction] {
        try annotationStore.interactions(for: contactID)
    }

    func record(interaction: Interaction) throws {
        try annotationStore.record(interaction: interaction)
    }

    func saveChanges(for contact: Contact) throws {
        try annotationStore.upsertAnnotation(for: contact)
    }

    /// Applies BetterContacts' own data on top of the address book entry.
    /// Annotations win over any overlapping system contact field; the
    /// last logged interaction becomes the contact's touchpoint date.
    private func hydrate(
        _ contact: inout Contact,
        annotation: ContactAnnotationEntity?,
        latestInteractionDate: Date?
    ) {
        if let annotation {
            contact.tags = Set(annotation.tags)
            contact.location = annotation.location
            if !annotation.notes.isEmpty {
                contact.notes = annotation.notes
            }
            contact.isCloseCircle = annotation.isCloseCircle
        }
        contact.lastInteractionDate = latestInteractionDate
    }
}
