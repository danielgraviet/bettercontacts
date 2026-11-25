import Contacts
import Domain
import Foundation

struct ContactCardFields: Equatable, Sendable {
    var firstName: String
    var lastName: String
    var organization: String
    var phones: [String]
    var emails: [String]
    var birthday: MonthDay?

    init(contact: Contact? = nil) {
        firstName = contact?.firstName ?? ""
        lastName = contact?.lastName ?? ""
        organization = contact?.organization ?? ""
        phones = contact?.phoneNumbers ?? []
        emails = contact?.emailAddresses ?? []
        birthday = contact?.birthday
    }

    var cleaned: Self {
        var result = self
        result.firstName = Self.trim(firstName)
        result.lastName = Self.trim(lastName)
        result.organization = Self.trim(organization)
        result.phones = phones.map(Self.trim).filter { !$0.isEmpty }
        result.emails = emails.map(Self.trim).filter { !$0.isEmpty }
        return result
    }

    var canSave: Bool {
        let values = cleaned
        return !values.firstName.isEmpty || !values.lastName.isEmpty || !values.organization.isEmpty
            || !values.phones.isEmpty || !values.emails.isEmpty
    }

    func apply(to contact: inout Contact) {
        contact.firstName = firstName
        contact.lastName = lastName
        contact.organization = organization.isEmpty ? nil : organization
        contact.phoneNumbers = phones
        contact.emailAddresses = emails
        contact.birthday = birthday
    }

    func vCard() throws -> Data {
        let card = CNMutableContact()
        card.givenName = firstName
        card.familyName = lastName
        card.organizationName = organization
        card.phoneNumbers = phones.map { CNLabeledValue(label: CNLabelOther, value: CNPhoneNumber(stringValue: $0)) }
        card.emailAddresses = emails.map { CNLabeledValue(label: CNLabelOther, value: $0 as NSString) }
        card.birthday = birthday.map { DateComponents(month: $0.month, day: $0.day) }
        return try CNContactVCardSerialization.data(with: [card])
    }

    private static func trim(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
protocol AddressBookEditing {
    func saveContact(_ fields: ContactCardFields, replacing original: Contact?) throws -> Contact
    func deleteContact(id: String) throws
}

enum AddressBookError: LocalizedError {
    case notFound

    var errorDescription: String? { "This contact is no longer available." }
}
