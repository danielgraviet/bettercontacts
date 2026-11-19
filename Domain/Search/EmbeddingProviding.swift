import Foundation

/// Produces a numeric vector representing the meaning of a piece of text.
///
/// The domain depends only on this seam: the app supplies the on-device
/// NaturalLanguage implementation, and tests supply a deterministic fake.
public protocol EmbeddingProviding: Sendable {
    /// A vector for `text`, or nil if no embedding can be produced.
    func embedding(for text: String) -> [Double]?
}
