import Domain
import Testing

@Suite("VectorMath")
struct VectorMathTests {

    @Test("returns one for parallel vectors")
    func returnsOneForParallelVectors() {
        // When comparing a vector with a scaled copy of itself
        let similarity = VectorMath.cosineSimilarity([1, 2, 3], [2, 4, 6])

        // Then they are perfectly similar
        #expect(abs(similarity - 1.0) < 0.000001)
    }

    @Test("returns minus one for opposite vectors")
    func returnsMinusOneForOppositeVectors() {
        // When comparing a vector with its negation
        let similarity = VectorMath.cosineSimilarity([1, 0], [-1, 0])

        // Then they are perfectly dissimilar
        #expect(abs(similarity + 1.0) < 0.000001)
    }

    @Test("returns zero for orthogonal vectors")
    func returnsZeroForOrthogonalVectors() {
        // When comparing perpendicular vectors
        let similarity = VectorMath.cosineSimilarity([1, 0, 0], [0, 1, 0])

        // Then they share no direction
        #expect(abs(similarity) < 0.000001)
    }

    @Test("returns zero for empty or mismatched vectors")
    func returnsZeroForEmptyOrMismatchedVectors() {
        // When comparing vectors that cannot be aligned
        // Then the result is always a safe zero
        #expect(VectorMath.cosineSimilarity([], []) == 0)
        #expect(VectorMath.cosineSimilarity([1, 0], [1, 0, 0]) == 0)
    }

    @Test("returns zero when either vector has zero magnitude")
    func returnsZeroWhenEitherVectorHasZeroMagnitude() {
        // When comparing against a zero vector
        let similarity = VectorMath.cosineSimilarity([0, 0], [1, 2])

        // Then the result is a safe zero instead of a division by zero
        #expect(similarity == 0)
    }
}
