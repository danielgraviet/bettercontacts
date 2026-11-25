import Domain
import Foundation

/// Fixed, realistic data used by UI tests (launched with
/// `-uitest-sample-contacts`) so the suite never depends on the simulator's
/// address book or any permission dialog.
final class SampleContactProvider: ContactSourceProviding, AddressBookEditing {
    private lazy var contacts = Self.samples()

    func fetchAllContacts() async throws -> [Contact] { contacts }

    func saveContact(_ fields: ContactCardFields, replacing original: Contact?) throws -> Contact {
        if let original {
            guard let index = contacts.firstIndex(where: { $0.id == original.id }) else { throw AddressBookError.notFound }
            fields.apply(to: &contacts[index])
            return contacts[index]
        }

        var contact = Contact(id: UUID().uuidString, firstName: "", lastName: "")
        fields.apply(to: &contact)
        contacts.append(contact)
        return contact
    }

    func deleteContact(id: String) throws {
        contacts.removeAll { $0.id == id }
    }

    private static func samples() -> [Contact] {
        let now = Date()
        return [
            Contact(
                id: "sample-ada",
                firstName: "Ada",
                lastName: "Lovelace",
                organization: "Analytical Engine Society",
                phoneNumbers: ["+44 20 7946 0958"],
                emailAddresses: ["ada@example.com"],
                birthday: MonthDay(month: 12, day: 10),
                location: "London",
                notes: "Pioneer of algorithmic thinking.",
                tags: ["pioneers"],
                isCloseCircle: true,
                createdAt: now.addingTimeInterval(-21 * 86_400)
            ),
            Contact(
                id: "sample-alan",
                firstName: "Alan",
                lastName: "Turing",
                organization: "Bletchley Park",
                phoneNumbers: ["+44 20 7946 0318"],
                emailAddresses: ["alan@example.com"],
                location: "Bletchley",
                notes: "Runs, thinks, repeats.",
                tags: ["mathematics"],
                isCloseCircle: false,
                createdAt: now,
                lastInteractionDate: now.addingTimeInterval(-2 * 86_400)
            ),
            Contact(
                id: "sample-grace",
                firstName: "Grace",
                lastName: "Hopper",
                organization: "US Navy",
                phoneNumbers: ["+1 555 010 2030"],
                emailAddresses: ["grace@example.com"],
                birthday: MonthDay(month: 12, day: 9),
                location: "New York",
                notes: "Compiles relationships as well as code.",
                tags: ["navy", "compilers"],
                isCloseCircle: true,
                createdAt: now,
                lastInteractionDate: nil
            )
        ]
    }
}
