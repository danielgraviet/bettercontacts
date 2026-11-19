import Foundation

/// Pure filtering over a list of contacts. Order is always preserved.
public enum ContactFilterEngine {
    /// Returns the contacts that match every non-empty facet of the filter,
    /// in their original order.
    public static func apply(_ filter: ContactFilter, to contacts: [Contact]) -> [Contact] {
        guard !filter.isEmpty else { return contacts }
        return contacts.filter { matches(filter, contact: $0) }
    }

    private static func matches(_ filter: ContactFilter, contact: Contact) -> Bool {
        if filter.onlyCloseCircle && !contact.isCloseCircle {
            return false
        }
        if filter.onlyWithBirthdays && contact.birthday == nil {
            return false
        }
        if filter.onlyWithPhoneNumbers && contact.phoneNumbers.isEmpty {
            return false
        }
        if !filter.tags.isEmpty && filter.tags.isDisjoint(with: contact.tags) {
            return false
        }
        if let location = filter.location?.trimmingCharacters(in: .whitespaces), !location.isEmpty {
            guard contact.location?.looselyContains(location) == true else {
                return false
            }
        }
        if let interval = filter.lastInteractionWithin {
            guard let lastInteraction = contact.lastInteractionDate,
                  interval.contains(lastInteraction) else {
                return false
            }
        }
        return true
    }
}
