import Foundation

/// How often each relationship should be maintained, in days.
public struct TouchpointPolicy: Equatable, Sendable {
    /// Close-circle contacts get a short cadence.
    public var closeCircleDays: Int
    /// Everyone else gets a long one.
    public var otherContactsDays: Int

    public init(closeCircleDays: Int = 14, otherContactsDays: Int = 120) {
        self.closeCircleDays = closeCircleDays
        self.otherContactsDays = otherContactsDays
    }

    /// The app's default cadence.
    public static let standard = TouchpointPolicy()

    /// The cadence a given contact is held to.
    public func cadenceDays(for contact: Contact) -> Int {
        contact.isCloseCircle ? closeCircleDays : otherContactsDays
    }
}
