import Domain
import Foundation
import Observation

/// Drives the contact list: loads contacts, applies natural language search,
/// filtering, and sorting, and keeps the reminders feed current.
@MainActor
@Observable
final class ContactListViewModel {
    private let repository: ContactRepositoryStoring
    private let addressBook: AddressBookEditing?
    let usesSystemContacts: Bool
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
    private(set) var loadError: (any Error)?
    var actionError: String?

    private(set) var lastLoggedInteraction: Interaction?
    private(set) var snoozes: [String: Date] = [:]
    private var history: [String: [Interaction]] = [:]
    private var sourceTouchpointDates: [String: Date] = [:]
    private var appliedSearchText = ""
    private var parsedQuery = ParsedQuery()
    private var reminderDate = Date.distantPast
    private var isLoading = false

    init(
        repository: ContactRepositoryStoring,
        embedder: EmbeddingProviding,
        policy: TouchpointPolicy = .standard,
        calendar: Calendar = .current,
        addressBook: AddressBookEditing? = nil,
        usesSystemContacts: Bool = false,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.addressBook = addressBook
        self.usesSystemContacts = usesSystemContacts
        self.searchEngine = SearchEngine(embedder: embedder)
        self.policy = policy
        self.calendar = calendar
        self.now = now
    }

    // MARK: Loading

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let snapshot = try await repository.loadSnapshot()
            history = snapshot.history
            snoozes = snapshot.snoozes
            sourceTouchpointDates = Dictionary(uniqueKeysWithValues: snapshot.contacts.compactMap { contact in
                contact.lastInteractionDate.map { (contact.id, $0) }
            })
            allContacts = snapshot.hydratedContacts
            loadError = nil
            isLoaded = true
            recompute()
        } catch {
            loadError = error
            if error is ContactAccessError {
                allContacts = []
                history = [:]
                sourceTouchpointDates = [:]
                lastLoggedInteraction = nil
                isLoaded = false
                recompute()
            }
        }
    }

    var canEditAddressBook: Bool { addressBook != nil }

    func saveContact(_ fields: ContactCardFields, replacing original: Contact?) throws {
        guard let addressBook else { return }
        let saved = try addressBook.saveContact(fields.cleaned, replacing: original)
        if let index = allContacts.firstIndex(where: { $0.id == saved.id }) {
            ContactCardFields(contact: saved).apply(to: &allContacts[index])
        } else {
            allContacts.append(saved)
        }
        recompute()
    }

    func deleteContact(_ contact: Contact) -> Bool {
        guard let addressBook else { return false }
        do {
            try addressBook.deleteContact(id: contact.id)
            allContacts.removeAll { $0.id == contact.id }
            if lastLoggedInteraction?.contactID == contact.id { lastLoggedInteraction = nil }
            recompute()
            return true
        } catch {
            actionError = "Couldn’t delete contact. \(error.localizedDescription)"
            return false
        }
    }

    // MARK: Intentions from the views

    func setSearchText(_ text: String) {
        searchText = text
        guard text != appliedSearchText, !NaturalLanguageQueryParser.isIncompleteMeetingQuery(text) else { return }
        appliedSearchText = text
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

    @discardableResult
    func logInteraction(_ contact: Contact, kind: InteractionKind, date: Date? = nil, note: String? = nil) -> Bool {
        let entry = Interaction(contactID: contact.id, date: date ?? now(), kind: kind, note: note)
        do {
            try repository.record(interaction: entry)
            lastLoggedInteraction = entry
            updateHistory(for: entry.contactID, adding: entry)
            return true
        } catch {
            actionError = "Couldn’t log touchpoint. \(error.localizedDescription)"
            return false
        }
    }

    func updateInteraction(_ entry: Interaction) -> Bool {
        do {
            try repository.update(interaction: entry)
            updateHistory(for: entry.contactID, removing: entry.id, adding: entry)
            return true
        } catch {
            actionError = "Couldn’t update touchpoint. \(error.localizedDescription)"
            return false
        }
    }

    func undoLastTouchpoint() {
        guard let entry = lastLoggedInteraction else { return }
        do {
            try repository.remove(interaction: entry)
            lastLoggedInteraction = nil
            updateHistory(for: entry.contactID, removing: entry.id)
        } catch {
            actionError = "Couldn’t undo touchpoint. \(error.localizedDescription)"
        }
    }

    private func updateHistory(for contactID: String, removing id: UUID? = nil, adding entry: Interaction? = nil) {
        var entries = history[contactID, default: []].filter { $0.id != id }
        if let entry { entries.append(entry) }
        entries.sort { $0.date > $1.date }
        history[contactID] = entries.isEmpty ? nil : entries
        if let index = allContacts.firstIndex(where: { $0.id == contactID }) {
            allContacts[index].lastInteractionDate = [sourceTouchpointDates[contactID], entries.first?.date].compactMap { $0 }.max()
        }
        recompute()
    }

    func snoozeReminder(for contact: Contact, days: Int) {
        guard days > 0, let date = calendar.date(byAdding: .day, value: days, to: now()) else { return }
        saveSnooze(until: date, for: contact)
    }

    func resumeReminder(for contact: Contact) {
        saveSnooze(until: nil, for: contact)
    }

    private func saveSnooze(until: Date?, for contact: Contact) {
        do {
            try repository.saveSnooze(until: until, for: contact.id)
            snoozes[contact.id] = until
            recomputeReminders()
        } catch {
            actionError = "Couldn’t update reminder. \(error.localizedDescription)"
        }
    }

    func refreshForCurrentTime() {
        parsedQuery = NaturalLanguageQueryParser.parse(appliedSearchText, now: now(), calendar: calendar)
        recompute()
    }

    /// Persists edits made on the detail screen (tags, location, notes,
    /// close-circle membership) and refreshes derived state locally.
    func saveAnnotations(_ annotations: ContactAnnotations, for contactID: String) {
        do {
            try repository.saveAnnotations(annotations, for: contactID)
            if let index = allContacts.firstIndex(where: { $0.id == contactID }) {
                annotations.apply(to: &allContacts[index])
            }
            recompute()
        } catch {
            actionError = "Couldn’t save contact details. \(error.localizedDescription)"
        }
    }

    // MARK: Derived state for the views

    func interactions(for contact: Contact) -> [Interaction] {
        history[contact.id, default: []]
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

    var currentDate: Date { now() }

    var yesterday: Date {
        calendar.date(byAdding: .day, value: -1, to: now()) ?? now()
    }

    func touchpointDateLabel(_ date: Date) -> String {
        if calendar.isDate(date, inSameDayAs: now()) { return "Today" }
        if calendar.isDate(date, inSameDayAs: yesterday) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    var activeSnoozes: [String: Date] {
        snoozes.filter { $0.value > reminderDate }
    }

    var overdueTouchpointReminders: [SmartReminder] {
        let active = activeSnoozes
        return touchpointReminders.filter { active[$0.contact.id] == nil }
    }

    var snoozedTouchpointReminders: [SmartReminder] {
        let active = activeSnoozes
        return touchpointReminders.filter { active[$0.contact.id] != nil }
    }

    private var touchpointReminders: [SmartReminder] {
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
            result = searchEngine.search(parsedQuery, in: result, interactionHistory: history)
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
        reminderDate = now()
        reminders = SmartReminderEngine.reminders(
            for: allContacts,
            policy: policy,
            now: reminderDate,
            calendar: calendar
        )
    }
}
