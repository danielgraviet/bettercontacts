import Foundation

/// The annual recurrence of a birthday: a month and a day, without a year.
///
/// Real contacts often have a birthday with no known birth year, so the
/// domain treats the pair as a recurring calendar event, not a fixed date.
public struct MonthDay: Equatable, Hashable, Codable, Sendable {
    public let month: Int
    public let day: Int

    public init(month: Int, day: Int) {
        self.month = month
        self.day = day
    }
}
