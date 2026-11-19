import Domain
import Testing

@Suite("TouchpointEngine")
struct TouchpointEngineTests {
    private let policy = TouchpointPolicy(closeCircleDays: 14, otherContactsDays: 120)

    @Test("is not due before the cadence has elapsed")
    func isNotDueBeforeTheCadenceHasElapsed() {
        // Given a close-circle contact contacted 9 days ago (cadence: 14 days)
        let contact = makeContact(
            id: "grace",
            firstName: "Grace",
            isCloseCircle: true,
            lastInteractionDate: testDate(2001, 1, 1)
        )

        // When checking urgency on day 9
        let urgency = TouchpointEngine.urgency(
            for: contact,
            policy: policy,
            now: testDate(2001, 1, 10),
            calendar: testCalendar
        )

        // Then the touchpoint is not yet due
        #expect(urgency.isDue == false)
    }

    @Test("is due exactly on the day the cadence elapses")
    func isDueExactlyOnTheDayTheCadenceElapses() {
        // Given a close-circle contact contacted 14 days ago
        let contact = makeContact(
            id: "grace",
            firstName: "Grace",
            isCloseCircle: true,
            lastInteractionDate: testDate(2001, 1, 1)
        )

        // When checking urgency on day 14, the cadence boundary
        let urgency = TouchpointEngine.urgency(
            for: contact,
            policy: policy,
            now: testDate(2001, 1, 15),
            calendar: testCalendar
        )

        // Then the touchpoint is due, with nothing overdue yet
        #expect(urgency.isDue == true)
        #expect(urgency.daysOverdue == 0)
    }

    @Test("uses the short cadence for the close circle and the long one for everyone else")
    func usesShortCadenceForCloseCircleAndLongForEveryoneElse() {
        // Given a close-circle contact and a regular contact, both last met 14 days ago
        let close = makeContact(
            id: "close",
            firstName: "Ada",
            isCloseCircle: true,
            lastInteractionDate: testDate(2001, 1, 1)
        )
        let distant = makeContact(
            id: "distant",
            firstName: "Grace",
            isCloseCircle: false,
            lastInteractionDate: testDate(2001, 1, 1)
        )

        // When collecting due contacts on day 14
        let due = TouchpointEngine.dueContacts(
            in: [close, distant],
            policy: policy,
            now: testDate(2001, 1, 15),
            calendar: testCalendar
        )

        // Then only the close-circle contact (14-day cadence) is due; the other (120-day) is not
        #expect(due.map(\.contact.id) == ["close"])
    }

    @Test("measures staleness from when the contact was added when no interaction is logged")
    func measuresStalenessFromCreatedAtWhenNoInteractionIsLogged() {
        // Given a contact added on January 1st who has never been interacted with
        let contact = makeContact(id: "alan", firstName: "Alan", createdAt: testDate(2001, 1, 1))

        // When checking urgency on February 1st
        let urgency = TouchpointEngine.urgency(
            for: contact,
            policy: policy,
            now: testDate(2001, 2, 1),
            calendar: testCalendar
        )

        // Then 31 days have passed since the contact was added
        #expect(urgency.daysSinceLastInteraction == 31)
    }

    @Test("counts how many days past the cadence a contact is overdue")
    func countsHowManyDaysPastTheCadenceAContactIsOverdue() {
        // Given a close-circle contact last met 50 days ago (cadence: 14)
        let contact = makeContact(
            id: "grace",
            firstName: "Grace",
            isCloseCircle: true,
            lastInteractionDate: testDate(2000, 12, 1)
        )

        // When checking urgency on January 20th, 2001
        let urgency = TouchpointEngine.urgency(
            for: contact,
            policy: policy,
            now: testDate(2001, 1, 20),
            calendar: testCalendar
        )

        // Then the contact is 36 days overdue (50 - 14)
        #expect(urgency.daysOverdue == 36)
    }

    @Test("lists due contacts most overdue first")
    func listsDueContactsMostOverdueFirst() {
        // Given a contact 36 days overdue and one 3 days overdue
        let veryOverdue = makeContact(
            id: "very",
            firstName: "Ada",
            isCloseCircle: true,
            lastInteractionDate: testDate(2000, 12, 1)
        )
        let slightlyOverdue = makeContact(
            id: "slightly",
            firstName: "Grace",
            isCloseCircle: true,
            lastInteractionDate: testDate(2001, 1, 3)
        )

        // When collecting due contacts on January 20th
        let due = TouchpointEngine.dueContacts(
            in: [slightlyOverdue, veryOverdue],
            policy: policy,
            now: testDate(2001, 1, 20),
            calendar: testCalendar
        )

        // Then the most overdue contact leads the list
        #expect(due.map(\.contact.id) == ["very", "slightly"])
    }

    @Test("orders equally overdue contacts alphabetically by name")
    func ordersEquallyOverdueContactsAlphabeticallyByName() {
        // Given two equally overdue contacts named out of order
        let grace = makeContact(
            id: "grace",
            firstName: "Grace",
            isCloseCircle: true,
            lastInteractionDate: testDate(2000, 12, 1)
        )
        let ada = makeContact(
            id: "ada",
            firstName: "Ada",
            isCloseCircle: true,
            lastInteractionDate: testDate(2000, 12, 1)
        )

        // When collecting due contacts
        let due = TouchpointEngine.dueContacts(
            in: [grace, ada],
            policy: policy,
            now: testDate(2001, 1, 20),
            calendar: testCalendar
        )

        // Then the tie falls back to name order
        #expect(due.map(\.contact.id) == ["ada", "grace"])
    }

    @Test("leaves contacts that are not yet due out of the due list")
    func leavesContactsThatAreNotYetDueOutOfTheDueList() {
        // Given one overdue and one not-yet-due close-circle contact
        let overdue = makeContact(
            id: "overdue",
            firstName: "Ada",
            isCloseCircle: true,
            lastInteractionDate: testDate(2000, 12, 1)
        )
        let upToDate = makeContact(
            id: "fresh",
            firstName: "Grace",
            isCloseCircle: true,
            lastInteractionDate: testDate(2001, 1, 15)
        )

        // When collecting due contacts on January 20th
        let due = TouchpointEngine.dueContacts(
            in: [overdue, upToDate],
            policy: policy,
            now: testDate(2001, 1, 20),
            calendar: testCalendar
        )

        // Then only the overdue contact appears
        #expect(due.map(\.contact.id) == ["overdue"])
    }
}
