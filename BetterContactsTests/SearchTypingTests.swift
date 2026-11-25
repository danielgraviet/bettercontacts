@testable import BetterContacts
import Domain
import Testing

@Suite("Search while typing")
@MainActor
struct SearchTypingTests {
    @Test("keeps the current results while a meeting date is still being typed")
    func keepsCurrentResultsWhileTypingMeetingDate() async {
        // Given a contact list with Ada and Grace
        let repository = FakeContactRepository()
        repository.stubbedContacts = [
            makeContact(id: "ada", firstName: "Ada"),
            makeContact(id: "grace", firstName: "Grace")
        ]
        let viewModel = ContactListViewModel(repository: repository, embedder: FakeEmbedder([:]), calendar: testCalendar) {
            testDate(2001, 1, 5)
        }
        await viewModel.load()

        // When the user pauses before finishing “yesterday”
        viewModel.setSearchText("who did I meet yester")

        // Then the list still shows both contacts while the draft remains editable
        #expect(viewModel.visibleContacts.map(\.id) == ["ada", "grace"])
        #expect(viewModel.searchText == "who did I meet yester")
    }
}
