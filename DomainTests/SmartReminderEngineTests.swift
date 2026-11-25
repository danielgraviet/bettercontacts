import Domain
import Testing

@Suite("SmartReminderEngine")
struct SmartReminderEngineTests {
    private let policy = TouchpointPolicy(closeCircleDays: 14, otherContactsDays: 120)
    private let now = testDate(2001, 1, 5)

    @Test("reminds about a birthday that is within the horizon")
    func remindsAboutABirthdayWithinTheHorizon() {
        // Given a contact whose birthday is 5 days away
        let ada = makeContact(id: "ada", firstName: "Ada", birthday: MonthDay(month: 1, day: 10))

        // When computing reminders
        let reminders = SmartReminderEngine.reminders(for: [ada], policy: policy, now: now, calendar: testCalendar)

        // Then one birthday reminder exists, 5 days out
        #expect(reminders.map(\.reason) == [.upcomingBirthday(daysUntil: 5)])
    }

    @Test("does not remind about birthdays beyond the horizon")
    func doesNotRemindAboutBirthdaysBeyondTheHorizon() {
        // Given a contact whose birthday is 152 days away, with a 30-day horizon
        let grace = makeContact(id: "grace", firstName: "Grace", birthday: MonthDay(month: 6, day: 1))

        // When computing reminders
        let reminders = SmartReminderEngine.reminders(
            for: [grace],
            policy: policy,
            now: now,
            birthdayHorizonDays: 30,
            calendar: testCalendar
        )

        // Then no reminders exist
        #expect(reminders.isEmpty)
    }

    @Test("reminds about a contact whose touchpoint is overdue")
    func remindsAboutAContactWhoseTouchpointIsOverdue() {
        // Given a close-circle contact last met 35 days ago (21 days overdue)
        let alan = makeContact(
            id: "alan",
            firstName: "Alan",
            isCloseCircle: true,
            lastInteractionDate: testDate(2000, 12, 1)
        )

        // When computing reminders on January 5th
        let reminders = SmartReminderEngine.reminders(for: [alan], policy: policy, now: now, calendar: testCalendar)

        // Then one touchpoint reminder exists, 21 days overdue
        #expect(reminders.map(\.reason) == [.overdueTouchpoint(daysOverdue: 21)])
    }

    @Test("does not remind about up-to-date contacts")
    func doesNotRemindAboutUpToDateContacts() {
        // Given a regular contact added today who has never been interacted with
        let fresh = makeContact(id: "fresh", firstName: "Ada", createdAt: now)

        // When computing reminders
        let reminders = SmartReminderEngine.reminders(for: [fresh], policy: policy, now: now, calendar: testCalendar)

        // Then no reminders exist
        #expect(reminders.isEmpty)
    }

    @Test("creates separate birthday and touchpoint reminders for the same contact")
    func createsSeparateBirthdayAndTouchpointRemindersForTheSameContact() {
        // Given a close-circle contact, overdue for a touchpoint, whose birthday is 5 days away
        let ada = makeContact(
            id: "ada",
            firstName: "Ada",
            birthday: MonthDay(month: 1, day: 10),
            isCloseCircle: true,
            lastInteractionDate: testDate(2000, 12, 1)
        )

        // When computing reminders
        let reminders = SmartReminderEngine.reminders(for: [ada], policy: policy, now: now, calendar: testCalendar)

        // Then both a birthday reminder and a touchpoint reminder exist
        let expected: Set<SmartReminder.Reason> = [
            .upcomingBirthday(daysUntil: 5),
            .overdueTouchpoint(daysOverdue: 21)
        ]
        #expect(Set(reminders.map(\.reason)) == expected)
    }

    @Test("ranks the most overdue contact ahead of a birthday that is tomorrow")
    func ranksTheMostOverdueContactAheadOfABirthdayThatIsTomorrow() {
        // Given a contact 21 days overdue for a touchpoint and one whose birthday is tomorrow
        let overdue = makeContact(
            id: "overdue",
            firstName: "Ada",
            isCloseCircle: true,
            lastInteractionDate: testDate(2000, 12, 1)
        )
        let birthdayTomorrow = makeContact(
            id: "tomorrow",
            firstName: "Grace",
            birthday: MonthDay(month: 1, day: 6)
        )

        // When computing reminders
        let reminders = SmartReminderEngine.reminders(
            for: [birthdayTomorrow, overdue],
            policy: policy,
            now: now,
            calendar: testCalendar
        )

        // Then the overdue touchpoint (action date: 21 days ago) comes first,
        // and tomorrow's birthday (action date: tomorrow) comes second
        #expect(reminders.map(\.contact.id) == ["overdue", "tomorrow"])
    }

    @Test("orders upcoming birthdays soonest first")
    func ordersUpcomingBirthdaysSoonestFirst() {
        // Given birthdays 5 and 12 days away, listed out of order
        let later = makeContact(id: "later", firstName: "Ada", birthday: MonthDay(month: 1, day: 17))
        let sooner = makeContact(id: "sooner", firstName: "Grace", birthday: MonthDay(month: 1, day: 10))

        // When computing reminders
        let reminders = SmartReminderEngine.reminders(
            for: [later, sooner],
            policy: policy,
            now: now,
            calendar: testCalendar
        )

        // Then the sooner birthday is listed first
        #expect(reminders.map(\.contact.id) == ["sooner", "later"])
    }

    @Test("breaks exact action-date ties alphabetically by name")
    func breaksExactActionDateTiesAlphabeticallyByName() {
        // Given two contacts whose birthdays are both tomorrow
        let grace = makeContact(id: "grace", firstName: "Grace", birthday: MonthDay(month: 1, day: 6))
        let ada = makeContact(id: "ada", firstName: "Ada", birthday: MonthDay(month: 1, day: 6))

        // When computing reminders
        let reminders = SmartReminderEngine.reminders(
            for: [grace, ada],
            policy: policy,
            now: now,
            calendar: testCalendar
        )

        // Then the tie falls back to name order
        #expect(reminders.map(\.contact.id) == ["ada", "grace"])
    }
}
