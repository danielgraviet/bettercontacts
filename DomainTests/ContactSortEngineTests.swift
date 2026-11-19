import Domain
import Testing

@Suite("ContactSortEngine")
struct ContactSortEngineTests {

    @Test("sorts names alphabetically in natural order, so 2 comes before 10")
    func sortsNamesAlphabeticallyInNaturalOrder() {
        // Given names containing numbers
        let ten = makeContact(id: "ten", firstName: "Contact", lastName: "10")
        let two = makeContact(id: "two", firstName: "Contact", lastName: "2")
        let ada = makeContact(id: "ada", firstName: "Ada", lastName: "Lovelace")

        // When sorting alphabetically
        let result = ContactSortEngine.sorted([ten, two, ada], by: .alphabetical, now: referenceNow)

        // Then names are alphabetical with numbers compared naturally
        #expect(result.map(\.id) == ["ada", "two", "ten"])
    }

    @Test("sorts soonest birthdays first across a year boundary")
    func sortsSoonestBirthdaysFirstAcrossYearBoundary() {
        // Given today in July 2001, a January birthday, and a December birthday
        let now = testDate(2001, 7, 1)
        let januaryBirthday = makeContact(id: "january", firstName: "Ada", birthday: MonthDay(month: 1, day: 5))
        let decemberBirthday = makeContact(id: "december", firstName: "Grace", birthday: MonthDay(month: 12, day: 24))

        // When sorting by soonest birthday
        let result = ContactSortEngine.sorted([januaryBirthday, decemberBirthday], by: .soonestBirthday, now: now)

        // Then the December birthday (176 days away) precedes the January one (188 days away)
        #expect(result.map(\.id) == ["december", "january"])
    }

    @Test("sorts contacts without birthdays last when sorting by soonest birthday")
    func sortsContactsWithoutBirthdaysLastWhenSortingBySoonestBirthday() {
        // Given one contact with and one without a birthday
        let withBirthday = makeContact(id: "with", firstName: "Grace", birthday: MonthDay(month: 3, day: 3))
        let withoutBirthday = makeContact(id: "without", firstName: "Ada")

        // When sorting by soonest birthday
        let result = ContactSortEngine.sorted([withoutBirthday, withBirthday], by: .soonestBirthday, now: referenceNow)

        // Then the contact without a birthday goes last, even though Ada sorts first alphabetically
        #expect(result.map(\.id) == ["with", "without"])
    }

    @Test("sorts by most recent interaction first, with never-contacted contacts last")
    func sortsByMostRecentInteractionFirstWithNeverContactedLast() {
        // Given contacts met at different times, and one never met
        let metRecently = makeContact(id: "recent", firstName: "Ada", lastInteractionDate: testDate(2001, 1, 4))
        let metEarlier = makeContact(id: "earlier", firstName: "Grace", lastInteractionDate: testDate(2000, 12, 20))
        let neverMet = makeContact(id: "never", firstName: "Alan")

        // When sorting by most recent interaction
        let result = ContactSortEngine.sorted(
            [metEarlier, neverMet, metRecently],
            by: .mostRecentlyInteracted,
            now: referenceNow
        )

        // Then recency wins over name order, and the never-contacted contact goes last
        #expect(result.map(\.id) == ["recent", "earlier", "never"])
    }

    @Test("sorts the most neglected relationships first")
    func sortsTheMostNeglectedRelationshipsFirst() {
        // Given contacts last contacted 2 and 16 days ago, and one added a
        // year ago who was never contacted at all
        let metTwoDaysAgo = makeContact(id: "two-days", firstName: "Ada", lastInteractionDate: testDate(2001, 1, 3))
        let metSixteenDaysAgo = makeContact(id: "sixteen-days", firstName: "Grace", lastInteractionDate: testDate(2000, 12, 20))
        let neverMet = makeContact(id: "never", firstName: "Alan", createdAt: testDate(2000, 1, 1))
        let now = testDate(2001, 1, 5)

        // When sorting by relationship staleness
        let result = ContactSortEngine.sorted(
            [metTwoDaysAgo, metSixteenDaysAgo, neverMet],
            by: .mostStaleRelationship,
            now: now
        )

        // Then the longest-neglected contact comes first
        #expect(result.map(\.id) == ["never", "sixteen-days", "two-days"])
    }

    @Test("breaks staleness ties alphabetically by name")
    func breaksStalenessTiesAlphabeticallyByName() {
        // Given two equally stale contacts whose names are in reverse alphabetical order
        let grace = makeContact(id: "grace", firstName: "Grace", lastInteractionDate: testDate(2001, 1, 3))
        let ada = makeContact(id: "ada", firstName: "Ada", lastInteractionDate: testDate(2001, 1, 3))

        // When sorting by staleness
        let result = ContactSortEngine.sorted([grace, ada], by: .mostStaleRelationship, now: testDate(2001, 1, 5))

        // Then equal staleness falls back to name order
        #expect(result.map(\.id) == ["ada", "grace"])
    }
}
