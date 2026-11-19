import Foundation

/// Pure sorting. Every ordering is deterministic: ties are broken by display
/// name so equal inputs always sort identically.
public enum ContactSortEngine {
    public static func sorted(
        _ contacts: [Contact],
        by sort: ContactSort,
        now: Date,
        calendar: Calendar = .current
    ) -> [Contact] {
        switch sort {
        case .alphabetical:
            return contacts.sorted(by: alphabetically)
        case .soonestBirthday:
            return contacts.sorted { bySoonestBirthday($0, $1, now: now, calendar: calendar) }
        case .mostRecentlyInteracted:
            return contacts.sorted(by: byMostRecentInteraction)
        case .mostStaleRelationship:
            return contacts.sorted { byMostStale($0, $1, now: now, calendar: calendar) }
        }
    }

    /// Natural (localized) comparison, so "Contact 2" sorts before "Contact 10".
    private static func alphabetically(_ lhs: Contact, _ rhs: Contact) -> Bool {
        lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
    }

    /// Soonest next birthday first; contacts without a birthday always sort last.
    private static func bySoonestBirthday(
        _ lhs: Contact,
        _ rhs: Contact,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        switch (lhs.birthday, rhs.birthday) {
        case let (.some(lhsBirthday), .some(rhsBirthday)):
            let lhsDays = BirthdayService.daysUntilBirthday(of: lhsBirthday, now: now, calendar: calendar)
            let rhsDays = BirthdayService.daysUntilBirthday(of: rhsBirthday, now: now, calendar: calendar)
            if lhsDays != rhsDays {
                return lhsDays < rhsDays
            }
            return alphabetically(lhs, rhs)
        case (.none, .some):
            return false
        case (.some, .none):
            return true
        case (.none, .none):
            return alphabetically(lhs, rhs)
        }
    }

    /// Most recent interaction first; never-contacted contacts always sort last.
    private static func byMostRecentInteraction(_ lhs: Contact, _ rhs: Contact) -> Bool {
        switch (lhs.lastInteractionDate, rhs.lastInteractionDate) {
        case let (.some(lhsDate), .some(rhsDate)):
            if lhsDate != rhsDate {
                return lhsDate > rhsDate
            }
            return alphabetically(lhs, rhs)
        case (.none, .some):
            return false
        case (.some, .none):
            return true
        case (.none, .none):
            return alphabetically(lhs, rhs)
        }
    }

    /// The most neglected relationship first. Never-contacted contacts count
    /// as stale from the day they were added.
    private static func byMostStale(
        _ lhs: Contact,
        _ rhs: Contact,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        let lhsDays = calendar.daysBetween(lhs.lastInteractionDate ?? lhs.createdAt, and: now)
        let rhsDays = calendar.daysBetween(rhs.lastInteractionDate ?? rhs.createdAt, and: now)
        if lhsDays != rhsDays {
            return lhsDays > rhsDays
        }
        return alphabetically(lhs, rhs)
    }
}
