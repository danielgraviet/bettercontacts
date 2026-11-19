import Foundation

/// Turns a raw search string like "who did I meet this week in Berlin #work"
/// into a structured `ParsedQuery` the search engine can filter and rank with.
public enum NaturalLanguageQueryParser {
    public static func parse(
        _ rawQuery: String,
        now: Date,
        calendar: Calendar = .current
    ) -> ParsedQuery {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return ParsedQuery() }

        var query = ParsedQuery()
        var working = trimmed

        query.dateRange = extractDateRange(from: &working, now: now, calendar: calendar)
        query.tags = extractTags(from: &working)
        query.location = extractLocation(from: &working)
        query.freeText = extractFreeText(from: working)
        return query
    }

    // MARK: - Date phrases

    private enum DatePhraseKind {
        case today, yesterday, thisWeek, lastWeek, thisMonth, lastMonth, thisYear
    }

    /// Longest phrases first, so a more specific match always wins.
    private static let datePhrases: [(phrase: String, kind: DatePhraseKind)] = [
        ("this week", .thisWeek),
        ("last week", .lastWeek),
        ("this month", .thisMonth),
        ("last month", .lastMonth),
        ("this year", .thisYear),
        ("today", .today),
        ("yesterday", .yesterday),
    ]

    private static func extractDateRange(
        from working: inout String,
        now: Date,
        calendar: Calendar
    ) -> DateInterval? {
        for (phrase, kind) in datePhrases {
            guard let range = wholeWordRange(of: phrase, in: working) else { continue }
            working = working.replacingCharacters(in: range, with: " ")
            return dateRange(for: kind, now: now, calendar: calendar)
        }
        return nil
    }

    /// Matches only when the phrase stands alone (bounded by spaces, the
    /// string's ends, or punctuation), so "today" does not match "todays".
    private static func wholeWordRange(of phrase: String, in text: String) -> Range<String.Index>? {
        guard let range = text.range(of: phrase) else { return nil }
        let startsClean = range.lowerBound == text.startIndex
            || !text[text.index(before: range.lowerBound)].isLetter
        let endsClean = range.upperBound == text.endIndex
            || !text[range.upperBound].isLetter
        return startsClean && endsClean ? range : nil
    }

    private static func dateRange(
        for kind: DatePhraseKind,
        now: Date,
        calendar: Calendar
    ) -> DateInterval? {
        switch kind {
        case .today:
            return calendar.dateInterval(of: .day, for: now)
        case .yesterday:
            guard let start = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) else {
                return nil
            }
            return calendar.dateInterval(of: .day, for: start)
        case .thisWeek:
            return calendar.dateInterval(of: .weekOfYear, for: now)
        case .lastWeek:
            return shiftedInterval(of: .weekOfYear, by: -1, from: now, calendar: calendar)
        case .thisMonth:
            return calendar.dateInterval(of: .month, for: now)
        case .lastMonth:
            return shiftedInterval(of: .month, by: -1, from: now, calendar: calendar)
        case .thisYear:
            return calendar.dateInterval(of: .year, for: now)
        }
    }

    private static func shiftedInterval(
        of component: Calendar.Component,
        by value: Int,
        from now: Date,
        calendar: Calendar
    ) -> DateInterval? {
        guard
            let current = calendar.dateInterval(of: component, for: now),
            let shiftedStart = calendar.date(byAdding: component, value: value, to: current.start)
        else {
            return nil
        }
        return calendar.dateInterval(of: component, for: shiftedStart)
    }

    // MARK: - Tags

    private static func extractTags(from working: inout String) -> Set<String> {
        guard let regex = try? NSRegularExpression(pattern: "#\\w+") else { return [] }
        let range = NSRange(working.startIndex..., in: working)
        let matches = regex.matches(in: working, range: range)
        let tags = Set(matches.map { match in
            let matchRange = Range(match.range, in: working) ?? working.startIndex..<working.startIndex
            return String(working[matchRange].dropFirst())
        })
        working = regex.stringByReplacingMatches(
            in: working,
            options: [],
            range: range,
            withTemplate: " "
        )
        return tags
    }

    // MARK: - Location

    /// Everything after " in " is taken as the location, up to the end of the
    /// query. Keywords that can precede it (dates, tags) are already removed
    /// by the time this runs, so "this week in New York City" resolves to
    /// "new york city". Trailing punctuation is ignored.
    private static func extractLocation(from working: inout String) -> String? {
        guard let range = working.range(of: " in ") else { return nil }
        let candidate = String(working[range.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard !candidate.isEmpty else { return nil }
        working = String(working[working.startIndex..<range.lowerBound])
        return candidate
    }

    // MARK: - Free text

    /// Words that exist only to make the query read like a sentence; they
    /// carry no meaning for matching.
    private static let fillerWords: Set<String> = [
        "who", "did", "i", "met", "meet", "with", "that", "the", "a", "an", "my",
        "of", "from", "in",
    ]

    private static func extractFreeText(from working: String) -> String? {
        // Trim punctuation from token edges: a sentence like "met this week?"
        // must not leave a stray "?" as meaningful free text.
        let words = working
            .split(separator: " ", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: CharacterSet.alphanumerics.inverted) }
            .filter { !$0.isEmpty && !fillerWords.contains(String($0)) }
        guard !words.isEmpty else { return nil }
        return words.joined(separator: " ")
    }
}
