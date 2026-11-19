import Domain
import Foundation
import Testing

@Suite("NaturalLanguageQueryParser")
struct NaturalLanguageQueryParserTests {
    private let now = testDate(2001, 1, 5)

    @Test("parses an empty query into an empty structured query")
    func parsesAnEmptyQueryIntoAnEmptyStructuredQuery() {
        // Given only whitespace
        // When parsing
        let query = NaturalLanguageQueryParser.parse("   ", now: now, calendar: testCalendar)

        // Then nothing was recognized
        #expect(query.isEmpty == true)
    }

    @Test("recognizes 'today' as the current calendar day")
    func recognizesTodayAsTheCurrentCalendarDay() {
        // When parsing a query mentioning today, January 5th 2001
        let query = NaturalLanguageQueryParser.parse("who did i meet today?", now: now, calendar: testCalendar)

        // Then the date range is exactly that day
        let expected = DateInterval(start: testDate(2001, 1, 5, hour: 0), end: testDate(2001, 1, 6, hour: 0))
        #expect(query.dateRange == expected)
    }

    @Test("recognizes 'this week' as the current calendar week")
    func recognizesThisWeekAsTheCurrentCalendarWeek() {
        // When parsing a query mentioning this week — the week of January 1st 2001, a Monday
        let query = NaturalLanguageQueryParser.parse("who did i meet this week", now: now, calendar: testCalendar)

        // Then the date range is that Monday through Sunday
        let expected = DateInterval(start: testDate(2001, 1, 1, hour: 0), end: testDate(2001, 1, 8, hour: 0))
        #expect(query.dateRange == expected)
    }

    @Test("recognizes 'last week' as the previous calendar week")
    func recognizesLastWeekAsThePreviousCalendarWeek() {
        // When parsing a query mentioning last week
        let query = NaturalLanguageQueryParser.parse("who did i meet last week", now: now, calendar: testCalendar)

        // Then the date range is the last full Monday-Sunday week
        let expected = DateInterval(start: testDate(2000, 12, 25, hour: 0), end: testDate(2001, 1, 1, hour: 0))
        #expect(query.dateRange == expected)
    }

    @Test("recognizes 'last month' across a year boundary")
    func recognizesLastMonthAcrossAYearBoundary() {
        // When parsing a query in January 2001 mentioning last month
        let query = NaturalLanguageQueryParser.parse("who did i meet last month", now: now, calendar: testCalendar)

        // Then the date range is December 2000
        let expected = DateInterval(start: testDate(2000, 12, 1, hour: 0), end: testDate(2001, 1, 1, hour: 0))
        #expect(query.dateRange == expected)
    }

    @Test("does not match date phrases inside other words")
    func doesNotMatchDatePhrasesInsideOtherWords() {
        // When parsing a query about weekends, not weeks
        let query = NaturalLanguageQueryParser.parse("friends from weekends", now: now, calendar: testCalendar)

        // Then no date range was recognized
        #expect(query.dateRange == nil)
    }

    @Test("extracts the location after 'in'")
    func extractsTheLocationAfterIn() {
        // When parsing a query about Berlin
        let query = NaturalLanguageQueryParser.parse("who did i meet in berlin", now: now, calendar: testCalendar)

        // Then Berlin is the location, and no free text remains
        #expect(query.location == "berlin")
        #expect(query.freeText == nil)
    }

    @Test("extracts hashtag tags from the query")
    func extractsHashtagTagsFromTheQuery() {
        // When parsing a query tagged #work
        let query = NaturalLanguageQueryParser.parse("friends #work", now: now, calendar: testCalendar)

        // Then 'work' is a tag filter
        #expect(query.tags == ["work"])
    }

    @Test("drops filler words from the free text")
    func dropsFillerWordsFromTheFreeText() {
        // When parsing a query written as a sentence
        let query = NaturalLanguageQueryParser.parse("friends from college", now: now, calendar: testCalendar)

        // Then only the meaningful words remain as free text
        #expect(query.freeText == "friends college")
    }

    @Test("leaves unrecognized phrases as free text")
    func leavesUnrecognizedPhrasesAsFreeText() {
        // When parsing a query the parser has no structured answer for
        let query = NaturalLanguageQueryParser.parse("paris photographer friends", now: now, calendar: testCalendar)

        // Then the whole phrase is kept as free text
        #expect(query.freeText == "paris photographer friends")
    }

    @Test("leaves no free text when a query is only filler words and punctuation")
    func leavesNoFreeTextWhenAQueryIsOnlyFillerWordsAndPunctuation() {
        // When parsing a full sentence whose only content is a date phrase
        let query = NaturalLanguageQueryParser.parse("who did i meet this week?", now: now, calendar: testCalendar)

        // Then the structured date range is all that remains
        #expect(query.dateRange != nil)
        #expect(query.freeText == nil)
    }

    @Test("parses a query that mixes dates, locations, and tags")
    func parsesAQueryThatMixesDatesLocationsAndTags() {
        // When parsing a full natural language query
        let query = NaturalLanguageQueryParser.parse(
            "who did i meet this week in new york city #design",
            now: now,
            calendar: testCalendar
        )

        // Then the date range, the multi-word location, and the tag are all recognized,
        // and nothing meaningful is left as free text
        let expectedRange = DateInterval(start: testDate(2001, 1, 1, hour: 0), end: testDate(2001, 1, 8, hour: 0))
        #expect(query.dateRange == expectedRange)
        #expect(query.location == "new york city")
        #expect(query.tags == ["design"])
        #expect(query.freeText == nil)
    }
}
