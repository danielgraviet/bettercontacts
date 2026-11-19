import Domain
import Testing
@testable import BetterContacts

/// A fake repository in the style of Google SWE book chapter 13: it holds
/// plain, observable state that tests assert against directly. No call
/// recording, no mock-verify interactions.
@MainActor
final class FakeContactRepository: ContactRepositoryStoring {
    var stubbedContacts: [Contact] = []
    private(set) var recordedInteractions: [Interaction] = []
    private(set) var savedContacts: [Contact] = []

    func allContacts() async throws -> [Contact] {
        stubbedContacts
    }

    func interactions(for contactID: String) throws -> [Interaction] {
        recordedInteractions.filter { $0.contactID == contactID }
    }

    func record(interaction: Interaction) throws {
        recordedInteractions.append(interaction)
    }

    func saveChanges(for contact: Contact) throws {
        savedContacts.append(contact)
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
            makeContact(id: "ada", firstName: "Ada"),
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
            makeContact(id: "never", firstName: "Alan", lastInteractionDate: nil),
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

    @Test("saving changes to a contact persists them and updates the list")
    func savingChangesToAContactPersistsThemAndUpdatesTheList() async {
        // Given a loaded contact with no tags yet
        let repository = FakeContactRepository()
        repository.stubbedContacts = [makeContact(id: "ada", firstName: "Ada")]
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()

        // When the user saves a tag for that contact
        var updated = repository.stubbedContacts[0]
        updated.tags = ["work"]
        viewModel.saveChanges(to: updated)

        // Then the change is persisted and reflected in the list state
        #expect(repository.savedContacts.map(\.tags) == [["work"]])
        #expect(viewModel.allContacts.first?.tags == ["work"])
    }
}
