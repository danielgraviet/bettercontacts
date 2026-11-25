@testable import BetterContacts
import Domain
import Testing

@Suite("ContactRepository")
@MainActor
struct ContactRepositoryTests {
    @Test("reloads edited contact annotations after they are cleared")
    func reloadsEditedContactAnnotationsAfterTheyAreCleared() async throws {
        // Given a contact with previously saved private details
        let contact = makeContact(id: "ada", firstName: "Ada")
        let repository = ContactRepository(
            contactSource: FixedContactSource(contacts: [contact]),
            annotationStore: AnnotationStore(inMemory: true)
        )
        let previous = ContactAnnotations(tags: ["work"], location: "London", notes: "Met at work", isCloseCircle: true)
        try repository.saveAnnotations(previous, for: "ada")

        // When the user clears those details and reloads
        let cleared = ContactAnnotations(tags: [], location: nil, notes: "", isCloseCircle: false)
        try repository.saveAnnotations(cleared, for: "ada")
        let contacts = try await repository.allContacts()

        // Then the reloaded contact has its original address-book data and cleared annotations
        #expect(contacts == [contact])
    }

    @Test("uses the newest logged touchpoint to hydrate a contact")
    func usesTheNewestLoggedTouchpointToHydrateAContact() async throws {
        // Given two records for Ada and one for someone else
        let contact = makeContact(id: "ada", firstName: "Ada")
        let repository = ContactRepository(
            contactSource: FixedContactSource(contacts: [contact]),
            annotationStore: AnnotationStore(inMemory: true)
        )
        try repository.record(interaction: Interaction(contactID: "ada", date: testDate(2001, 1, 4), kind: .metInPerson))
        try repository.record(interaction: Interaction(contactID: "ada", date: testDate(2001, 1, 3), kind: .metInPerson))
        try repository.record(interaction: Interaction(contactID: "grace", date: testDate(2001, 1, 5), kind: .metInPerson))

        // When the repository reloads the contact
        let contacts = try await repository.allContacts()

        // Then the newest touchpoint belongs to Ada
        #expect(contacts.first?.lastInteractionDate == testDate(2001, 1, 4))
    }
}

private struct FixedContactSource: ContactSourceProviding {
    let contacts: [Contact]

    func fetchAllContacts() async throws -> [Contact] {
        contacts
    }
}

@Suite("Touchpoint history search")
@MainActor
struct TouchpointHistorySearchTests {
    @Test("finds yesterday’s meeting after a newer call")
    func findsYesterdaysMeetingAfterANewerCall() async throws {
        // Given Ada was met yesterday and called today
        let ada = makeContact(id: "ada", firstName: "Ada")
        let repository = ContactRepository(
            contactSource: FixedContactSource(contacts: [ada]), annotationStore: AnnotationStore(inMemory: true)
        )
        try repository.record(interaction: Interaction(contactID: "ada", date: testDate(2001, 1, 4), kind: .metInPerson))
        try repository.record(interaction: Interaction(contactID: "ada", date: testDate(2001, 1, 5), kind: .call))
        let viewModel = makeViewModel(repository)
        await viewModel.load()

        // When searching for yesterday’s meetings
        viewModel.setSearchText("Who did I meet yesterday?")

        // Then Ada appears
        #expect(viewModel.visibleContacts.map(\.id) == ["ada"])
    }

    @Test("excludes a call from meeting results")
    func excludesACallFromMeetingResults() async throws {
        // Given Ada was called yesterday
        let ada = makeContact(id: "ada", firstName: "Ada")
        let repository = ContactRepository(
            contactSource: FixedContactSource(contacts: [ada]), annotationStore: AnnotationStore(inMemory: true)
        )
        try repository.record(interaction: Interaction(contactID: "ada", date: testDate(2001, 1, 4), kind: .call))
        let viewModel = makeViewModel(repository)
        await viewModel.load()

        // When searching for yesterday’s meetings
        viewModel.setSearchText("Who did I meet yesterday?")

        // Then Ada is excluded
        #expect(viewModel.visibleContacts.isEmpty)
    }

    private func makeViewModel(_ repository: ContactRepository) -> ContactListViewModel {
        ContactListViewModel(repository: repository, embedder: FakeEmbedder([:]), calendar: testCalendar) {
            testDate(2001, 1, 5)
        }
    }
}
