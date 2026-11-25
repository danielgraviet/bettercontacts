import Foundation

/// Natural language search: applies every structured part of a parsed query
/// as a filter, then ranks whatever remains by semantic similarity of the
/// free text.
public struct SearchEngine: Sendable {
    private let embedder: EmbeddingProviding
    /// Similarities below this are treated as noise and dropped.
    private let minimumSimilarity: Double

    public init(embedder: EmbeddingProviding, minimumSimilarity: Double = 0.3) {
        self.embedder = embedder
        self.minimumSimilarity = minimumSimilarity
    }

    public func search(
        _ query: ParsedQuery,
        in contacts: [Contact],
        interactionHistory: [String: [Interaction]] = [:]
    ) -> [Contact] {
        guard !query.isEmpty else { return contacts }

        var candidates = contacts
        if let dateRange = query.dateRange {
            candidates = candidates.filter { contact in
                matchesDate(dateRange, kind: query.interactionKind, contact: contact, history: interactionHistory[contact.id])
            }
        }
        if let location = query.location, !location.isEmpty {
            candidates = candidates.filter { contact in
                contact.location?.looselyContains(location) == true
            }
        }
        if !query.tags.isEmpty {
            candidates = candidates.filter { !$0.tags.isDisjoint(with: query.tags) }
        }

        guard let freeText = query.freeText, !freeText.isEmpty else {
            return candidates
        }

        let queryVector = embedder.embedding(for: freeText)
        let words = freeText.split(whereSeparator: \.isWhitespace).map(String.init)

        return candidates
            .compactMap { contact -> (contact: Contact, score: Double)? in
                score(contact, for: freeText, queryVector: queryVector, words: words).map { (contact, $0) }
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.contact.displayName.localizedStandardCompare(rhs.contact.displayName) == .orderedAscending
            }
            .map(\.contact)
    }

    private func matchesDate(
        _ range: DateInterval,
        kind: InteractionKind?,
        contact: Contact,
        history: [Interaction]?
    ) -> Bool {
        if let history {
            return history.contains {
                (kind == nil || $0.kind == kind) && $0.date >= range.start && $0.date < range.end
            }
        }
        // Some callers have an imported last-touchpoint date without its underlying log.
        guard let date = contact.lastInteractionDate else { return false }
        return date >= range.start && date < range.end
    }

    private func score(_ contact: Contact, for phrase: String, queryVector: [Double]?, words: [String]) -> Double? {
        // Literal matches rank above the maximum cosine similarity of 1.
        if contact.displayName.looselyContains(phrase) { return 3 }
        let text = contact.searchableText
        if text.looselyContains(phrase) { return 2 }

        guard let queryVector else {
            return words.contains { text.looselyContains($0) } ? 0 : nil
        }
        guard let contactVector = embedder.embedding(for: text) else { return nil }
        let similarity = VectorMath.cosineSimilarity(queryVector, contactVector)
        return similarity >= minimumSimilarity ? similarity : nil
    }
}
