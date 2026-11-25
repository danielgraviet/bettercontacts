import Foundation

extension Calendar {
    /// Whole calendar days between two dates, ignoring time-of-day.
    /// A negative result means `later` is before `earlier`.
    func daysBetween(_ earlier: Date, and later: Date) -> Int {
        let from = startOfDay(for: earlier)
        let end = startOfDay(for: later)
        return dateComponents([.day], from: from, to: end).day ?? 0
    }
}
