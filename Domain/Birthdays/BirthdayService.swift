import Foundation

/// Birthday math, treated as a recurring calendar event rather than a fixed date.
public enum BirthdayService {
    /// Days until the birthday's next occurrence; 0 means today. Never negative.
    public static func daysUntilBirthday(
        of birthday: MonthDay,
        now: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard let next = nextOccurrence(of: birthday, onOrAfter: now, calendar: calendar) else {
            return Int.max
        }
        return max(0, calendar.daysBetween(now, and: next))
    }

    /// The next date on or after `now` that the birthday falls on.
    ///
    /// A February 29 birthday is celebrated on February 28 in non-leap years.
    /// Returns nil for dates that cannot exist in any year.
    public static func nextOccurrence(
        of birthday: MonthDay,
        onOrAfter now: Date,
        calendar: Calendar
    ) -> Date? {
        let startOfToday = calendar.startOfDay(for: now)
        let currentYear = calendar.component(.year, from: now)
        for year in [currentYear, currentYear + 1] {
            if let date = birthdayDate(of: birthday, inYear: year, calendar: calendar),
               date >= startOfToday {
                return date
            }
        }
        return nil
    }

    /// Contacts whose birthday falls within `withinDays` of `now`, soonest first.
    /// Contacts without a birthday are ignored. Ties break alphabetically by name.
    public static func upcomingBirthdays(
        in contacts: [Contact],
        withinDays horizon: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> [Contact] {
        contacts
            .compactMap { contact -> (contact: Contact, daysUntil: Int)? in
                guard let birthday = contact.birthday else { return nil }
                let days = daysUntilBirthday(of: birthday, now: now, calendar: calendar)
                guard days <= horizon else { return nil }
                return (contact, days)
            }
            .sorted { lhs, rhs in
                if lhs.daysUntil != rhs.daysUntil {
                    return lhs.daysUntil < rhs.daysUntil
                }
                return lhs.contact.displayName.localizedStandardCompare(rhs.contact.displayName) == .orderedAscending
            }
            .map(\.contact)
    }

    /// Clamps the day into the month's real range, so February 29 becomes
    /// February 28 in non-leap years.
    private static func birthdayDate(
        of birthday: MonthDay,
        inYear year: Int,
        calendar: Calendar
    ) -> Date? {
        guard
            let firstOfMonth = calendar.date(from: DateComponents(year: year, month: birthday.month)),
            let dayRange = calendar.range(of: .day, in: .month, for: firstOfMonth)
        else {
            return nil
        }
        let clampedDay = min(birthday.day, dayRange.count)
        return calendar.date(from: DateComponents(year: year, month: birthday.month, day: clampedDay))
    }
}
