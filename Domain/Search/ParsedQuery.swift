import Foundation

/// A natural language search query, broken into the parts the app can act on.
/// Produced by `NaturalLanguageQueryParser`; consumed by `SearchEngine`.
public struct ParsedQuery: Equatable, Sendable {
    /// e.g. "this week" → the current calendar week.
    public var dateRange: DateInterval?
    /// e.g. "in berlin" → "berlin".
    public var location: String?
    /// e.g. "#work" → {"work"}.
    public var tags: Set<String>
    /// Everything meaningful left over, for semantic matching.
    public var freeText: String?

    public init(
        dateRange: DateInterval? = nil,
        location: String? = nil,
        tags: Set<String> = [],
        freeText: String? = nil
    ) {
        self.dateRange = dateRange
        self.location = location
        self.tags = tags
        self.freeText = freeText
    }

    public var isEmpty: Bool {
        dateRange == nil
            && (location?.isEmpty ?? true)
            && tags.isEmpty
            && (freeText?.isEmpty ?? true)
    }
}
