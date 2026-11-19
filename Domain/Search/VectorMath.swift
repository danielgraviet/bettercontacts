import Foundation

/// Small vector helpers used for semantic search ranking.
public enum VectorMath {
    /// Cosine similarity of two equal-length vectors, in [-1, 1].
    ///
    /// Returns 0 for empty, mismatched, or zero-magnitude vectors, so callers
    /// never divide by zero and never see NaN on degenerate input.
    public static func cosineSimilarity(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }
        var dotProduct = 0.0
        var lhsMagnitude = 0.0
        var rhsMagnitude = 0.0
        for index in lhs.indices {
            dotProduct += lhs[index] * rhs[index]
            lhsMagnitude += lhs[index] * lhs[index]
            rhsMagnitude += rhs[index] * rhs[index]
        }
        guard lhsMagnitude > 0, rhsMagnitude > 0 else { return 0 }
        return dotProduct / (lhsMagnitude.squareRoot() * rhsMagnitude.squareRoot())
    }
}
