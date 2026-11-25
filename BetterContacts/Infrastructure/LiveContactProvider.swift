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
final class LiveContactProvider: ContactSourceProviding, AddressBookEditing {
    private let store = CNContactStore()

    private static let keys: [CNKeyDescriptor] = [
        CNContactIdentifierKey as NSString,
        CNContactGivenNameKey as NSString,
        CNContactFamilyNameKey as NSString,
        CNContactOrganizationNameKey as NSString,
        CNContactPhoneNumbersKey as NSString,
        CNContactEmailAddressesKey as NSString,
        CNContactBirthdayKey as NSString
    ]

    func fetchAllContacts() async throws -> [Contact] {
        guard await requestAccess() else {
            throw ContactAccessError.notAuthorized
        }

        var contacts: [Contact] = []
        let request = CNContactFetchRequest(keysToFetch: Self.keys)
        try store.enumerateContacts(with: request) { cnContact, _ in
            contacts.append(Self.contact(from: cnContact))
        }
        return contacts
    }

    func saveContact(_ fields: ContactCardFields, replacing original: Contact?) throws -> Contact {
        let card = try original.map { try mutableContact(id: $0.id, keys: Self.keys) } ?? CNMutableContact()
        let previous = original.map { ContactCardFields(contact: $0) }
        if fields.firstName != previous?.firstName { card.givenName = fields.firstName }
        if fields.lastName != previous?.lastName { card.familyName = fields.lastName }
        if fields.organization != previous?.organization { card.organizationName = fields.organization }
        if fields.phones != previous?.phones {
            card.phoneNumbers = labeledValues(
                fields.phones, existing: card.phoneNumbers, key: { $0.stringValue }, makeValue: CNPhoneNumber.init(stringValue:)
            )
        }
        if fields.emails != previous?.emails {
            card.emailAddresses = labeledValues(
                fields.emails, existing: card.emailAddresses, key: { $0 as String }, makeValue: { $0 as NSString }
            )
        }
        if fields.birthday != previous?.birthday {
            card.birthday = fields.birthday.map { DateComponents(month: $0.month, day: $0.day) }
        }

        let request = CNSaveRequest()
        if original == nil {
            request.add(card, toContainerWithIdentifier: nil)
        } else {
            request.update(card)
        }
        try store.execute(request)
        return Self.contact(from: card)
    }

    func deleteContact(id: String) throws {
        let request = CNSaveRequest()
        request.delete(try mutableContact(id: id, keys: [CNContactIdentifierKey as NSString]))
        try store.execute(request)
    }

    private func mutableContact(id: String, keys: [CNKeyDescriptor]) throws -> CNMutableContact {
        let contact = try store.unifiedContact(withIdentifier: id, keysToFetch: keys)
        guard let mutable = contact.mutableCopy() as? CNMutableContact else { throw AddressBookError.notFound }
        return mutable
    }

    private func labeledValues<Value: NSCopying & NSSecureCoding>(
        _ values: [String],
        existing: [CNLabeledValue<Value>],
        key: (Value) -> String,
        makeValue: (String) -> Value
    ) -> [CNLabeledValue<Value>] {
        // Preserve the identifiers and labels of entries the user has kept.
        var remaining = existing
        return values.map { value in
            if let index = remaining.firstIndex(where: { key($0.value) == value }) {
                return remaining.remove(at: index)
            }
            return CNLabeledValue(label: CNLabelOther, value: makeValue(value))
        }
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
            birthday: birthday
        )
    }
}
