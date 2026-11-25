@testable import BetterContacts
import Domain
import Foundation
import Testing

/// A fake repository in the style of Google SWE book chapter 13: it holds
/// plain, observable state that tests assert against directly. No call
/// recording, no mock-verify interactions.
@MainActor
final class FakeContactRepository: ContactRepositoryStoring {
    var stubbedContacts: [Contact] = []
    private(set) var recordedInteractions: [Interaction] = []
    var writeError: (any Error)?

    func allContacts() async throws -> [Contact] {
        stubbedContacts
    }

    func interactions(for contactID: String) throws -> [Interaction] {
        recordedInteractions.filter { $0.contactID == contactID }
    }

    func record(interaction: Interaction) throws {
        if let writeError { throw writeError }
        recordedInteractions.append(interaction)
    }

    func saveAnnotations(_ annotations: ContactAnnotations, for contactID: String) throws {
        if let writeError { throw writeError }
        if let index = stubbedContacts.firstIndex(where: { $0.id == contactID }) {
            annotations.apply(to: &stubbedContacts[index])
        }
    }
}

@Suite("ContactListViewModel")
@MainActor
struct ContactListViewModelTests {

    private func makeViewModel(
        repository: FakeContactRepository,
        embedder: EmbeddingProviding = FakeEmbedder([:])
    ) -> ContactListViewModel {
        ContactListViewModel(
            repository: repository,
            embedder: embedder,
            policy: TouchpointPolicy(closeCircleDays: 14, otherContactsDays: 120),
            calendar: testCalendar,
            now: { testDate(2001, 1, 5) }
        )
    }

    @Test("shows every contact alphabetically after loading")
    func showsEveryContactAlphabeticallyAfterLoading() async {
        // Given contacts stored out of alphabetical order
        let repository = FakeContactRepository()
        repository.stubbedContacts = [
            makeContact(id: "grace", firstName: "Grace"),
            makeContact(id: "ada", firstName: "Ada")
        ]

        // When the list loads
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()

        // Then contacts appear alphabetically by name
        #expect(viewModel.visibleContacts.map(\.id) == ["ada", "grace"])
    }

    @Test("answers 'who did I meet this week?' with only this week's meetings")
    func answersWhoDidIMeetThisWeekWithOnlyThisWeeksMeetings() async {
        // Given contacts met this week, in December, and never
        let repository = FakeContactRepository()
        repository.stubbedContacts = [
            makeContact(id: "this-week", firstName: "Ada", lastInteractionDate: testDate(2001, 1, 4)),
            makeContact(id: "december", firstName: "Grace", lastInteractionDate: testDate(2000, 12, 15)),
            makeContact(id: "never", firstName: "Alan", lastInteractionDate: nil)
        ]

        // When searching with a natural language query
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()
        viewModel.setSearchText("who did I meet this week?")

        // Then only the contact met during the week of January 1st remains
        #expect(viewModel.visibleContacts.map(\.id) == ["this-week"])
    }

    @Test("stops suggesting a touchpoint after one is logged")
    func stopsSuggestingATouchpointAfterOneIsLogged() async {
        // Given a close-circle contact 21 days overdue for a catch-up
        let overdueContact = makeContact(
            id: "overdue",
            firstName: "Ada",
            isCloseCircle: true,
            lastInteractionDate: testDate(2000, 12, 1)
        )
        let repository = FakeContactRepository()
        repository.stubbedContacts = [overdueContact]

        // When the list loads, the contact is due for a touchpoint
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()
        #expect(viewModel.overdueTouchpointReminders.map(\.contact.id) == ["overdue"])

        // And when the user logs a meeting today
        viewModel.logInteraction(overdueContact, kind: .metInPerson)

        // Then the touchpoint is no longer suggested, and the log was persisted
        #expect(viewModel.overdueTouchpointReminders.isEmpty)
        #expect(repository.recordedInteractions.count == 1)
        #expect(repository.recordedInteractions.first?.kind == .metInPerson)
    }

    @Test("surfaces upcoming birthdays in the reminders feed")
    func surfacesUpcomingBirthdaysInTheRemindersFeed() async {
        // Given a contact whose birthday is 5 days away
        let repository = FakeContactRepository()
        repository.stubbedContacts = [
            makeContact(id: "ada", firstName: "Ada", birthday: MonthDay(month: 1, day: 10))
        ]

        // When the list loads
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()

        // Then the reminders feed lists the birthday
        #expect(viewModel.upcomingBirthdayReminders.map(\.contact.id) == ["ada"])
    }

    @Test("shows updated tags after saving contact annotations")
    func showsUpdatedTagsAfterSavingContactAnnotations() async {
        // Given a loaded contact with no tags yet
        let repository = FakeContactRepository()
        repository.stubbedContacts = [makeContact(id: "ada", firstName: "Ada")]
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()

        // When the user saves a tag for that contact
        let annotations = ContactAnnotations(tags: ["work"], location: nil, notes: "", isCloseCircle: false)
        viewModel.saveAnnotations(annotations, for: "ada")

        // Then the contact carries the tag in the list
        #expect(viewModel.visibleContacts.first?.tags == ["work"])
    }

    @Test("keeps contacts visible when a touchpoint write fails")
    func keepsContactsVisibleWhenATouchpointWriteFails() async {
        // Given a loaded contact and a repository that rejects writes
        let contact = makeContact(id: "ada", firstName: "Ada")
        let repository = FakeContactRepository()
        repository.stubbedContacts = [contact]
        repository.writeError = CocoaError(.fileWriteOutOfSpace)
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()

        // When the user tries to log a call
        viewModel.logInteraction(contact, kind: .call)

        // Then the list stays intact and reports an action failure
        #expect(viewModel.loadError == nil)
        #expect(viewModel.visibleContacts == [contact])
        #expect(viewModel.actionError != nil)
    }
}
