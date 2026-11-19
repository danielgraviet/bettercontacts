import Domain
import Foundation
import Testing

@Suite("ContactFilterEngine")
struct ContactFilterEngineTests {

    @Test("returns every contact in its original order when the filter is empty")
    func returnsEveryContactInOriginalOrderWhenFilterIsEmpty() {
        // Given contacts inserted out of alphabetical order
        let grace = makeContact(id: "grace", firstName: "Grace")
        let ada = makeContact(id: "ada", firstName: "Ada")

        // When applying an empty filter
        let result = ContactFilterEngine.apply(ContactFilter(), to: [grace, ada])

        // Then nothing is filtered out or reordered
        #expect(result == [grace, ada])
    }

    @Test("keeps only close-circle contacts when onlyCloseCircle is on")
    func keepsOnlyCloseCircleContactsWhenOnlyCloseCircleIsOn() {
        // Given one close-circle contact and one regular contact
        let inner = makeContact(id: "inner", firstName: "Ada", isCloseCircle: true)
        let outer = makeContact(id: "outer", firstName: "Grace", isCloseCircle: false)

        // When filtering to the close circle only
        let result = ContactFilterEngine.apply(ContactFilter(onlyCloseCircle: true), to: [outer, inner])

        // Then only the close-circle contact remains
        #expect(result == [inner])
    }

    @Test("excludes contacts without birthdays when onlyWithBirthdays is on")
    func excludesContactsWithoutBirthdaysWhenOnlyWithBirthdaysIsOn() {
        // Given one contact with a birthday and one without
        let withBirthday = makeContact(id: "birthday", firstName: "Ada", birthday: MonthDay(month: 6, day: 10))
        let withoutBirthday = makeContact(id: "no-birthday", firstName: "Grace")

        // When filtering to contacts with birthdays only
        let result = ContactFilterEngine.apply(
            ContactFilter(onlyWithBirthdays: true),
            to: [withBirthday, withoutBirthday]
        )

        // Then only the contact with a birthday remains
        #expect(result == [withBirthday])
    }

    @Test("excludes contacts without phone numbers when onlyWithPhoneNumbers is on")
    func excludesContactsWithoutPhoneNumbersWhenOnlyWithPhoneNumbersIsOn() {
        // Given one contact with a phone number and one without any
        let reachable = makeContact(id: "reachable", firstName: "Ada", phoneNumbers: ["555-0100"])
        let unreachable = makeContact(id: "unreachable", firstName: "Grace", phoneNumbers: [])

        // When filtering to contacts with phone numbers only
        let result = ContactFilterEngine.apply(
            ContactFilter(onlyWithPhoneNumbers: true),
            to: [reachable, unreachable]
        )

        // Then only the contact with a phone number remains
        #expect(result == [reachable])
    }

    @Test("keeps contacts that share at least one tag with the filter")
    func keepsContactsThatShareAtLeastOneTagWithTheFilter() {
        // Given a contact tagged 'work' and 'friends', and one tagged 'family'
        let colleague = makeContact(id: "colleague", firstName: "Ada", tags: ["work", "friends"])
        let cousin = makeContact(id: "cousin", firstName: "Grace", tags: ["family"])

        // When filtering by the 'work' tag
        let result = ContactFilterEngine.apply(ContactFilter(tags: ["work"]), to: [colleague, cousin])

        // Then only the contact carrying that tag remains
        #expect(result == [colleague])
    }

    @Test("matches locations case-insensitively")
    func matchesLocationsCaseInsensitively() {
        // Given a contact tagged with a mixed-case location
        let newYorker = makeContact(id: "new-yorker", firstName: "Ada", location: "New York City")
        let berliner = makeContact(id: "berliner", firstName: "Grace", location: "Berlin")

        // When filtering by a lowercase location
        let result = ContactFilterEngine.apply(ContactFilter(location: "new york"), to: [newYorker, berliner])

        // Then the mixed-case location still matches
        #expect(result == [newYorker])
    }

    @Test("excludes contacts without a location when filtering by location")
    func excludesContactsWithoutALocationWhenFilteringByLocation() {
        // Given a contact with no location tag
        let untagged = makeContact(id: "untagged", firstName: "Ada", location: nil)
        let berliner = makeContact(id: "berliner", firstName: "Grace", location: "Berlin")

        // When filtering by location
        let result = ContactFilterEngine.apply(ContactFilter(location: "berlin"), to: [untagged, berliner])

        // Then only the contact with a matching location remains
        #expect(result == [berliner])
    }

    @Test("keeps contacts whose last interaction falls inside the date range")
    func keepsContactsWhoseLastInteractionFallsInsideTheDateRange() {
        // Given one contact met during the first week of January 2001 and one met in December
        let metThisWeek = makeContact(id: "recent", firstName: "Ada", lastInteractionDate: testDate(2001, 1, 4))
        let metInDecember = makeContact(id: "december", firstName: "Grace", lastInteractionDate: testDate(2000, 12, 20))
        let firstWeekOfJanuary = DateInterval(
            start: testDate(2001, 1, 1, hour: 0),
            end: testDate(2001, 1, 8, hour: 0)
        )

        // When filtering to interactions within that week
        let result = ContactFilterEngine.apply(
            ContactFilter(lastInteractionWithin: firstWeekOfJanuary),
            to: [metThisWeek, metInDecember]
        )

        // Then only the contact met during the week remains
        #expect(result == [metThisWeek])
    }

    @Test("excludes contacts with no logged interaction when filtering by interaction date range")
    func excludesContactsWithNoLoggedInteractionWhenFilteringByInteractionDateRange() {
        // Given a contact who has never been logged as met
        let neverMet = makeContact(id: "never-met", firstName: "Ada", lastInteractionDate: nil)
        let firstWeekOfJanuary = DateInterval(
            start: testDate(2001, 1, 1, hour: 0),
            end: testDate(2001, 1, 8, hour: 0)
        )

        // When filtering to interactions within that week
        let result = ContactFilterEngine.apply(
            ContactFilter(lastInteractionWithin: firstWeekOfJanuary),
            to: [neverMet]
        )

        // Then the contact without an interaction is excluded
        #expect(result.isEmpty)
    }
}
