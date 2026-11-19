import Domain
import Foundation

/// The composition root: everything the views need, wired together in one
/// place. Tests and UI tests build their own instance with fakes.
@MainActor
struct AppEnvironment {
    let repository: ContactRepository
    let embedder: EmbeddingProviding
    let now: () -> Date
    let calendar: Calendar

    static func live() -> AppEnvironment {
        let contactSource = LiveContactProvider()
        let annotationStore = AnnotationStore()
        return AppEnvironment(
            repository: ContactRepository(contactSource: contactSource, annotationStore: annotationStore),
            embedder: NaturalLanguageEmbeddingProvider(),
            now: { Date() },
            calendar: .current
        )
    }

    static func uiTestSample() -> AppEnvironment {
        let contactSource = SampleContactProvider()
        let annotationStore = AnnotationStore(inMemory: true)
        return AppEnvironment(
            repository: ContactRepository(contactSource: contactSource, annotationStore: annotationStore),
            embedder: NaturalLanguageEmbeddingProvider(),
            now: { Date() },
            calendar: .current
        )
    }
}
