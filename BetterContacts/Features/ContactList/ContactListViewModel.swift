import Domain
import Foundation
import Observation

/// Drives the contact list: loads contacts, applies natural language search,
/// filtering, and sorting, and keeps the reminders feed current.
@MainActor
@Observable
final class ContactListViewModel {
    private let repository: ContactRepositoryStoring
    private let searchEngine: SearchEngine
    private let policy: TouchpointPolicy
    private let calendar: Calendar
    private let now: () -> Date

    // MARK: State

    private(set) var allContacts: [Contact] = []
    private(set) var visibleContacts: [Contact] = []
    private(set) var reminders: [SmartReminder] = []
    private(set) var isLoaded = false
    private(set) var searchText = ""
    private(set) var filter = ContactFilter()
    private(set) var sort: ContactSort = .alphabetical
    private(set) var errorMessage: String?

    private var parsedQuery = ParsedQuery()

    init(
        repository: ContactRepositoryStoring,
        embedder: EmbeddingProviding,
        policy: TouchpointPolicy = .standard,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.searchEngine = SearchEngine(embedder: embedder)
        self.policy = policy
        self.calendar = calendar
        self.now = now
    }

    // MARK: Loading

    func load() async {
        do {
            allContacts = try await repository.allContacts()
            errorMessage = nil
            isLoaded = true
            recompute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Intentions from the views

    func setSearchText(_ text: String) {
        searchText = text
        parsedQuery = NaturalLanguageQueryParser.parse(text, now: now(), calendar: calendar)
        recomputeVisibleContacts()
    }

    func setFilter(_ newFilter: ContactFilter) {
        filter = newFilter
        recomputeVisibleContacts()
    }

    func setSort(_ newSort: ContactSort) {
        sort = newSort
        recomputeVisibleContacts()
    }

    /// Logs a touchpoint and immediately refreshes everything derived from it
    /// (staleness, ordering, reminders) without refetching the address book.
    func logInteraction(_ contact: Contact, kind: InteractionKind, note: String? = nil) {
        let interaction = Interaction(contactID: contact.id, date: now(), kind: kind, note: note)
        do {
            try repository.record(interaction: interaction)
            if let index = allContacts.firstIndex(where: { $0.id == contact.id }) {
                allContacts[index].lastInteractionDate = interaction.date
            }
            errorMessage = nil
            recompute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Persists edits made on the detail screen (tags, location, notes,
    /// close-circle membership) and refreshes derived state locally.
    func saveChanges(to contact: Contact) {
        do {
            try repository.saveChanges(for: contact)
            if let index = allContacts.firstIndex(where: { $0.id == contact.id }) {
                allContacts[index] = contact
            }
            errorMessage = nil
            recompute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Derived state for the views

    func interactions(for contact: Contact) -> [Interaction] {
        (try? repository.interactions(for: contact.id)) ?? []
    }

    func urgency(for contact: Contact) -> TouchpointUrgency {
        TouchpointEngine.urgency(for: contact, policy: policy, now: now(), calendar: calendar)
    }

    func daysUntilBirthday(of contact: Contact) -> Int? {
        guard let birthday = contact.birthday else { return nil }
        return BirthdayService.daysUntilBirthday(of: birthday, now: now(), calendar: calendar)
    }

    /// The freshest copy of a contact the list holds — a detail screen that
    /// received an old snapshot uses this to render current state.
    func currentContact(_ contact: Contact) -> Contact {
        allContacts.first(where: { $0.id == contact.id }) ?? contact
    }

    var overdueTouchpointReminders: [SmartReminder] {
        reminders.filter { reminder in
            if case .overdueTouchpoint = reminder.reason { return true }
            return false
        }
    }

    var upcomingBirthdayReminders: [SmartReminder] {
        reminders.filter { reminder in
            if case .upcomingBirthday = reminder.reason { return true }
            return false
        }
    }

    // MARK: Recomputation

    private func recompute() {
        recomputeVisibleContacts()
        recomputeReminders()
    }

    private func recomputeVisibleContacts() {
        var result = allContacts
        if !filter.isEmpty {
            result = ContactFilterEngine.apply(filter, to: result)
        }
        if !parsedQuery.isEmpty {
            result = searchEngine.search(parsedQuery, in: result)
            // With free text in play, semantic relevance is the most meaningful
            // order; the explicit sort takes over for everything else.
            if parsedQuery.freeText != nil {
                visibleContacts = result
                return
            }
        }
        visibleContacts = ContactSortEngine.sorted(result, by: sort, now: now(), calendar: calendar)
    }

    private func recomputeReminders() {
        reminders = SmartReminderEngine.reminders(
            for: allContacts,
            policy: policy,
            now: now(),
            calendar: calendar
        )
    }
}
