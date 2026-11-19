import Contacts
import Domain
import Foundation

enum ContactAccessError: LocalizedError, Equatable {
    case notAuthorized

    var errorDescription: String? {
        "BetterContacts needs access to your contacts. Enable access in Settings."
    }
}

/// Reads the user's address book through the system Contacts framework.
final class LiveContactProvider: ContactSourceProviding {
    private let store = CNContactStore()

    func fetchAllContacts() async throws -> [Contact] {
        guard await requestAccess() else {
            throw ContactAccessError.notAuthorized
        }

        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as NSString,
            CNContactGivenNameKey as NSString,
            CNContactFamilyNameKey as NSString,
            CNContactOrganizationNameKey as NSString,
            CNContactPhoneNumbersKey as NSString,
            CNContactEmailAddressesKey as NSString,
            CNContactBirthdayKey as NSString,
            CNContactNoteKey as NSString,
        ]

        var contacts: [Contact] = []
        let request = CNContactFetchRequest(keysToFetch: keys)
        try store.enumerateContacts(with: request) { cnContact, _ in
            contacts.append(Self.contact(from: cnContact))
        }
        return contacts
    }

    private func requestAccess() async -> Bool {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                store.requestAccess(for: .contacts) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    /// Maps one system contact into the domain's own terms. Everything the
    /// domain cannot express (jobs, addresses, IM names, …) is left behind.
    static func contact(from cnContact: CNContact) -> Contact {
        var birthday: MonthDay?
        if let components = cnContact.birthday,
           let month = components.month,
           let day = components.day,
           (1...12).contains(month),
           (1...31).contains(day) {
            birthday = MonthDay(month: month, day: day)
        }

        return Contact(
            id: cnContact.identifier,
            firstName: cnContact.givenName,
            lastName: cnContact.familyName,
            organization: cnContact.organizationName.isEmpty ? nil : cnContact.organizationName,
            phoneNumbers: cnContact.phoneNumbers.map { $0.value.stringValue },
            emailAddresses: cnContact.emailAddresses.map { String($0.value) },
            birthday: birthday,
            notes: cnContact.note
        )
    }
}
