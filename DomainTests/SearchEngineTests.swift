import Domain
import Foundation
import Testing

@Suite("SearchEngine")
struct SearchEngineTests {

    @Test("returns all contacts unchanged when the query is empty")
    func returnsAllContactsUnchangedWhenTheQueryIsEmpty() {
        // Given contacts and an empty query
        let grace = makeContact(id: "grace", firstName: "Grace")
        let ada = makeContact(id: "ada", firstName: "Ada")
        let engine = SearchEngine(embedder: FakeEmbedder([:]))

        // When searching with the empty query
        let result = engine.search(ParsedQuery(), in: [grace, ada])

        // Then every contact is returned in its original order
        #expect(result == [grace, ada])
    }

    @Test("keeps contacts met inside the queried date range and drops the rest")
    func keepsContactsMetInsideTheQueriedDateRangeAndDropsTheRest() {
        // Given contacts met this week, in December, and never
        let metThisWeek = makeContact(id: "this-week", firstName: "Ada", lastInteractionDate: testDate(2001, 1, 4))
        let metInDecember = makeContact(id: "december", firstName: "Grace", lastInteractionDate: testDate(2000, 12, 15))
        let neverMet = makeContact(id: "never", firstName: "Alan", lastInteractionDate: nil)
        let engine = SearchEngine(embedder: FakeEmbedder([:]))
        let thisWeek = ParsedQuery(
            dateRange: DateInterval(start: testDate(2001, 1, 1, hour: 0), end: testDate(2001, 1, 8, hour: 0))
        )

        // When searching for people met this week
        let result = engine.search(thisWeek, in: [metThisWeek, metInDecember, neverMet])

        // Then only the contact met inside the range remains
        #expect(result.map(\.id) == ["this-week"])
    }

    @Test("matches locations case-insensitively")
    func matchesLocationsCaseInsensitively() {
        // Given contacts tagged with mixed-case locations
        let berliner = makeContact(id: "berliner", firstName: "Ada", location: "Berlin")
        let munichResident = makeContact(id: "munich", firstName: "Grace", location: "Munich")
        let engine = SearchEngine(embedder: FakeEmbedder([:]))
        let inBerlin = ParsedQuery(location: "berlin")

        // When searching for people in berlin
        let result = engine.search(inBerlin, in: [berliner, munichResident])

        // Then the mixed-case location matches
        #expect(result.map(\.id) == ["berliner"])
    }

    @Test("ranks semantically similar contacts above dissimilar ones")
    func ranksSemanticallySimilarContactsAboveDissimilarOnes() {
        // Given a hiker and a sailor, and a similarity threshold of zero
        let hiker = makeContact(id: "hiker", firstName: "Ada", notes: "loves hiking")
        let sailor = makeContact(id: "sailor", firstName: "Grace", notes: "loves sailing")
        let engine = SearchEngine(embedder: FakeEmbedder(["hiking": [1, 0], "sailing": [0, 1]]), minimumSimilarity: 0)
        let hikingFriends = ParsedQuery(freeText: "friends who like hiking")

        // When searching for hiking friends
        let result = engine.search(hikingFriends, in: [sailor, hiker])

        // Then both remain, ranked with the hiker first
        #expect(result.map(\.id) == ["hiker", "sailor"])
    }

    @Test("drops contacts below the similarity threshold")
    func dropsContactsBelowTheSimilarityThreshold() {
        // Given a hiker and a sailor, and the default 0.3 threshold
        let hiker = makeContact(id: "hiker", firstName: "Ada", notes: "loves hiking")
        let sailor = makeContact(id: "sailor", firstName: "Grace", notes: "loves sailing")
        let engine = SearchEngine(embedder: FakeEmbedder(["hiking": [1, 0], "sailing": [0, 1]]))
        let hikingFriends = ParsedQuery(freeText: "friends who like hiking")

        // When searching for hiking friends
        let result = engine.search(hikingFriends, in: [sailor, hiker])

        // Then only the semantically matching hiker remains
        #expect(result.map(\.id) == ["hiker"])
    }

    @Test("falls back to plain text matching when the query has no embedding")
    func fallsBackToPlainTextMatchingWhenTheQueryHasNoEmbedding() {
        // Given a contact whose notes mention yoga, and an embedder that knows no such word
        let yogi = makeContact(id: "yogi", firstName: "Ada", notes: "teaches yoga on weekends")
        let hiker = makeContact(id: "hiker", firstName: "Grace", notes: "loves hiking")
        let engine = SearchEngine(embedder: FakeEmbedder(["hiking": [1, 0]]))
        let yogaFriends = ParsedQuery(freeText: "yoga friends")

        // When searching for yoga friends
        let result = engine.search(yogaFriends, in: [yogi, hiker])

        // Then the text match keeps the yoga teacher and drops the hiker
        #expect(result.map(\.id) == ["yogi"])
    }

    @Test("combines date filtering with semantic ranking")
    func combinesDateFilteringWithSemanticRanking() {
        // Given two hikers, one met this week and one met in December
        let metThisWeek = makeContact(
            id: "recent-hiker",
            firstName: "Ada",
            notes: "loves hiking",
            lastInteractionDate: testDate(2001, 1, 4)
        )
        let metInDecember = makeContact(
            id: "december-hiker",
            firstName: "Grace",
            notes: "loves hiking",
            lastInteractionDate: testDate(2000, 12, 15)
        )
        let engine = SearchEngine(embedder: FakeEmbedder(["hiking": [1, 0]]))
        let query = ParsedQuery(
            dateRange: DateInterval(start: testDate(2001, 1, 1, hour: 0), end: testDate(2001, 1, 8, hour: 0)),
            freeText: "friends who like hiking"
        )

        // When searching for hiking friends met this week
        let result = engine.search(query, in: [metInDecember, metThisWeek])

        // Then only the hiker met this week remains
        #expect(result.map(\.id) == ["recent-hiker"])
    }

    @Test("breaks similarity ties alphabetically by name")
    func breaksSimilarityTiesAlphabeticallyByName() {
        // Given two equally similar contacts named out of order
        let grace = makeContact(id: "grace", firstName: "Grace", notes: "loves hiking")
        let ada = makeContact(id: "ada", firstName: "Ada", notes: "loves hiking")
        let engine = SearchEngine(embedder: FakeEmbedder(["hiking": [1, 0]]))
        let hikingFriends = ParsedQuery(freeText: "hiking")

        // When searching for hiking friends
        let result = engine.search(hikingFriends, in: [grace, ada])

        // Then the tie falls back to name order
        #expect(result.map(\.id) == ["ada", "grace"])
    }
}
