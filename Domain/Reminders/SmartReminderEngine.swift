import Foundation

/// Turns raw contact data into the reminders the user actually sees:
/// a merged, ordered feed of overdue touchpoints and upcoming birthdays.
public enum SmartReminderEngine {
    /// All reminders for the given contacts, ordered by when the user should
    /// act: the most overdue touchpoint first, then the soonest birthday.
    public static func reminders(
        for contacts: [Contact],
        policy: TouchpointPolicy,
        now: Date,
        birthdayHorizonDays: Int = 30,
        calendar: Calendar = .current
    ) -> [SmartReminder] {
        var reminders: [SmartReminder] = []
        for contact in contacts {
            if let birthday = contact.birthday {
                let daysUntil = BirthdayService.daysUntilBirthday(of: birthday, now: now, calendar: calendar)
                if daysUntil <= birthdayHorizonDays {
                    reminders.append(SmartReminder(contact: contact, reason: .upcomingBirthday(daysUntil: daysUntil)))
                }
            }
            let urgency = TouchpointEngine.urgency(for: contact, policy: policy, now: now, calendar: calendar)
            if urgency.isDue {
                reminders.append(SmartReminder(contact: contact, reason: .overdueTouchpoint(daysOverdue: urgency.daysOverdue)))
            }
        }
        return reminders.sorted { lhs, rhs in
            let lhsDate = actionDate(of: lhs, now: now, calendar: calendar)
            let rhsDate = actionDate(of: rhs, now: now, calendar: calendar)
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            if lhs.contact.displayName != rhs.contact.displayName {
                return lhs.contact.displayName.localizedStandardCompare(rhs.contact.displayName) == .orderedAscending
            }
            return rank(of: lhs.reason) < rank(of: rhs.reason)
        }
    }

    /// When this reminder should be acted on. Overdue touchpoints map to the
    /// day they became due (in the past); birthdays map to the day itself.
    private static func actionDate(
        of reminder: SmartReminder,
        now: Date,
        calendar: Calendar
    ) -> Date {
        switch reminder.reason {
        case let .upcomingBirthday(daysUntil):
            return calendar.date(byAdding: .day, value: daysUntil, to: now) ?? now
        case let .overdueTouchpoint(daysOverdue):
            return calendar.date(byAdding: .day, value: -daysOverdue, to: now) ?? now
        }
    }

    /// Tie-break when one contact has both a birthday and an overdue touchpoint
    /// on the same action date: the birthday wins.
    private static func rank(of reason: SmartReminder.Reason) -> Int {
        switch reason {
        case .upcomingBirthday:
            return 0
        case .overdueTouchpoint:
            return 1
        }
    }
}
