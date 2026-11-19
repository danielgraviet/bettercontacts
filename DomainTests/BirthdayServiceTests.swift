import Domain
import Testing

@Suite("BirthdayService")
struct BirthdayServiceTests {

    @Test("returns zero days when the birthday is today")
    func returnsZeroDaysWhenBirthdayIsToday() {
        // Given January 5th, 2001 and a birthday on January 5th
        let now = testDate(2001, 1, 5)

        // When asking for the days until the next occurrence
        let days = BirthdayService.daysUntilBirthday(
            of: MonthDay(month: 1, day: 5),
            now: now,
            calendar: testCalendar
        )

        // Then the birthday is today
        #expect(days == 0)
    }

    @Test("counts the days until a birthday later in the same year")
    func countsDaysUntilBirthdayLaterInTheSameYear() {
        // Given January 5th and a birthday on January 20th
        let now = testDate(2001, 1, 5)

        // When asking for the days until the next occurrence
        let days = BirthdayService.daysUntilBirthday(
            of: MonthDay(month: 1, day: 20),
            now: now,
            calendar: testCalendar
        )

        // Then 15 days remain
        #expect(days == 15)
    }

    @Test("rolls over to the next year once the birthday has passed")
    func rollsOverToNextYearOnceBirthdayHasPassed() {
        // Given January 20th and a birthday on January 5th, already passed this year
        let now = testDate(2001, 1, 20)

        // When asking for the days until the next occurrence
        let days = BirthdayService.daysUntilBirthday(
            of: MonthDay(month: 1, day: 5),
            now: now,
            calendar: testCalendar
        )

        // Then the next occurrence is in 2002, 350 days away
        #expect(days == 350)
    }

    @Test("celebrates February 29 birthdays on February 28 in non-leap years")
    func celebratesFebruaryTwentyNineOnFebruaryTwentyEightInNonLeapYears() {
        // Given February 2001 (not a leap year) and a birthday on February 29th
        let now = testDate(2001, 2, 1)

        // When asking for the next occurrence
        let next = BirthdayService.nextOccurrence(
            of: MonthDay(month: 2, day: 29),
            onOrAfter: now,
            calendar: testCalendar
        )

        // Then it lands on February 28th
        #expect(next == testDate(2001, 2, 28, hour: 0))
    }

    @Test("keeps February 29 birthdays on February 29 in leap years")
    func keepsFebruaryTwentyNineInLeapYears() {
        // Given January 2004 (a leap year) and a birthday on February 29th
        let now = testDate(2004, 1, 1)

        // When asking for the next occurrence
        let next = BirthdayService.nextOccurrence(
            of: MonthDay(month: 2, day: 29),
            onOrAfter: now,
            calendar: testCalendar
        )

        // Then it stays on February 29th
        #expect(next == testDate(2004, 2, 29, hour: 0))
    }

    @Test("lists only contacts whose birthday falls within the horizon")
    func listsOnlyContactsWhoseBirthdayFallsWithinTheHorizon() {
        // Given birthdays 5 days away, 152 days away, and not set at all
        let now = testDate(2001, 1, 5)
        let soon = makeContact(id: "soon", firstName: "Ada", birthday: MonthDay(month: 1, day: 10))
        let far = makeContact(id: "far", firstName: "Grace", birthday: MonthDay(month: 6, day: 1))
        let none = makeContact(id: "none", firstName: "Alan")

        // When asking for birthdays within 30 days
        let result = BirthdayService.upcomingBirthdays(
            in: [soon, far, none],
            withinDays: 30,
            now: now,
            calendar: testCalendar
        )

        // Then only the contact 5 days out is listed
        #expect(result.map(\.id) == ["soon"])
    }

    @Test("sorts upcoming birthdays soonest first")
    func sortsUpcomingBirthdaysSoonestFirst() {
        // Given birthdays 12, 3, and 7 days away, listed out of order
        let now = testDate(2001, 1, 5)
        let onJanuary17 = makeContact(id: "17th", firstName: "Ada", birthday: MonthDay(month: 1, day: 17))
        let onJanuary8 = makeContact(id: "8th", firstName: "Grace", birthday: MonthDay(month: 1, day: 8))
        let onJanuary12 = makeContact(id: "12th", firstName: "Alan", birthday: MonthDay(month: 1, day: 12))

        // When asking for birthdays within 30 days
        let result = BirthdayService.upcomingBirthdays(
            in: [onJanuary17, onJanuary8, onJanuary12],
            withinDays: 30,
            now: now,
            calendar: testCalendar
        )

        // Then they are listed soonest first
        #expect(result.map(\.id) == ["8th", "12th", "17th"])
    }
}
