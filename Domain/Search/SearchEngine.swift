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

    public func search(_ query: ParsedQuery, in contacts: [Contact]) -> [Contact] {
        guard !query.isEmpty else { return contacts }

        var candidates = contacts
        if let dateRange = query.dateRange {
            candidates = candidates.filter { contact in
                contact.lastInteractionDate.map(dateRange.contains) == true
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

        // No embedding available for the query — fall back to plain text
        // matching, keeping any contact that matches at least one word.
        guard let queryVector = embedder.embedding(for: freeText) else {
            let words = freeText.split(separator: " ").map(String.init)
            return candidates.filter { contact in
                words.contains { contact.searchableText.looselyContains($0) }
            }
        }

        return candidates
            .compactMap { contact -> (contact: Contact, similarity: Double)? in
                guard let contactVector = embedder.embedding(for: contact.searchableText) else {
                    return nil
                }
                let similarity = VectorMath.cosineSimilarity(queryVector, contactVector)
                guard similarity >= minimumSimilarity else { return nil }
                return (contact, similarity)
            }
            .sorted { lhs, rhs in
                if lhs.similarity != rhs.similarity {
                    return lhs.similarity > rhs.similarity
                }
                return lhs.contact.displayName.localizedStandardCompare(rhs.contact.displayName) == .orderedAscending
            }
            .map(\.contact)
    }
}
