import Foundation

/// Scores every relationship by how overdue its next touchpoint is.
public enum TouchpointEngine {
    /// The urgency of a single contact's next touchpoint.
    public static func urgency(
        for contact: Contact,
        policy: TouchpointPolicy,
        now: Date,
        calendar: Calendar = .current
    ) -> TouchpointUrgency {
        let referenceDate = contact.lastInteractionDate ?? contact.createdAt
        let daysSince = calendar.daysBetween(referenceDate, and: now)
        return TouchpointUrgency(
            contact: contact,
            daysSinceLastInteraction: daysSince,
            cadenceDays: policy.cadenceDays(for: contact)
        )
    }

    /// The contacts whose touchpoint is due, most overdue first.
    /// Equally overdue contacts sort alphabetically by name.
    public static func dueContacts(
        in contacts: [Contact],
        policy: TouchpointPolicy,
        now: Date,
        calendar: Calendar = .current
    ) -> [TouchpointUrgency] {
        contacts
            .map { urgency(for: $0, policy: policy, now: now, calendar: calendar) }
            .filter(\.isDue)
            .sorted { lhs, rhs in
                if lhs.daysOverdue != rhs.daysOverdue {
                    return lhs.daysOverdue > rhs.daysOverdue
                }
                return lhs.contact.displayName.localizedStandardCompare(rhs.contact.displayName) == .orderedAscending
            }
    }
}
