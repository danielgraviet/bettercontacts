import Domain
import Foundation
@preconcurrency import NaturalLanguage

/// On-device word embeddings from Apple's NaturalLanguage framework. Averages
/// the vectors of the known words in a piece of text; private, offline, and
/// free — no API keys, no network calls, nothing leaves the device.
struct NaturalLanguageEmbeddingProvider: EmbeddingProviding {
    private let embedding: NLEmbedding?

    init(language: NLLanguage = .english) {
        embedding = NLEmbedding.wordEmbedding(for: language)
    }

    func embedding(for text: String) -> [Double]? {
        guard let embedding else { return nil }
        let words = text.lowercased().split { $0.isWhitespace || $0.isNewline || $0.isPunctuation }
        guard !words.isEmpty else { return nil }

        var vectors: [[Double]] = []
        for word in words {
            if let vector = embedding.vector(for: String(word)) {
                vectors.append(vector)
            }
        }
        guard !vectors.isEmpty else { return nil }

        var average = [Double](repeating: 0, count: vectors[0].count)
        for vector in vectors {
            for (index, component) in vector.enumerated() {
                average[index] += component
            }
        }
        return average.map { $0 / Double(vectors.count) }
    }
}
