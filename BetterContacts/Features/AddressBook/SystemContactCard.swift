import Contacts
import ContactsUI
import SwiftUI

struct SystemContactCard: View {
    let contactID: String

    @Environment(\.dismiss) private var dismiss
    @State private var contact: CNContact?
    @State private var errorMessage: String?

    private let store = CNContactStore()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()

            if let contact {
                ContactController(contact: contact, store: store)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Couldn’t open contact",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView("Opening contact…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            do {
                let keys = [CNContactViewController.descriptorForRequiredKeys()]
                contact = try store.unifiedContact(withIdentifier: contactID, keysToFetch: keys)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private struct ContactController: UIViewControllerRepresentable {
        let contact: CNContact
        let store: CNContactStore

        func makeUIViewController(context: Context) -> UINavigationController {
            let controller = CNContactViewController(for: contact)
            controller.contactStore = store
            controller.allowsEditing = true
            controller.allowsActions = true
            return UINavigationController(rootViewController: controller)
        }

        func updateUIViewController(_ controller: UINavigationController, context: Context) {}
    }
}
