import Domain
import SwiftUI

struct ContactCardEditor: View {
    let viewModel: ContactListViewModel
    let original: Contact?

    @Environment(\.dismiss) private var dismiss
    @State private var fields: ContactCardFields
    @State private var phones: [Entry]
    @State private var emails: [Entry]
    @State private var errorMessage: String?

    init(viewModel: ContactListViewModel, contact: Contact? = nil) {
        self.viewModel = viewModel
        original = contact
        let card = ContactCardFields(contact: contact)
        _fields = State(initialValue: card)
        _phones = State(initialValue: card.phones.map { Entry(value: $0) })
        _emails = State(initialValue: card.emails.map { Entry(value: $0) })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First Name", text: $fields.firstName)
                        .textContentType(.givenName)
                    TextField("Last Name", text: $fields.lastName)
                        .textContentType(.familyName)
                    TextField("Organization", text: $fields.organization)
                        .textContentType(.organizationName)
                }
                entries("Phone", rows: $phones, keyboard: .phonePad, contentType: .telephoneNumber)
                entries("Email", rows: $emails, keyboard: .emailAddress, contentType: .emailAddress)
                birthdaySection
            }
            .navigationTitle(original == nil ? "New Contact" : "Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Contact", action: save)
                        .disabled(!editedFields.canSave)
                }
            }
        }
        .alert("Couldn’t save contact", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var editedFields: ContactCardFields {
        var edited = fields
        edited.phones = phones.map(\.value)
        edited.emails = emails.map(\.value)
        return edited
    }

    private func entries(
        _ title: String,
        rows: Binding<[Entry]>,
        keyboard: UIKeyboardType,
        contentType: UITextContentType
    ) -> some View {
        Section(title) {
            ForEach(rows) { row in
                TextField(title, text: row.value)
                    .textContentType(contentType)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .onDelete { rows.wrappedValue.remove(atOffsets: $0) }
            Button("Add \(title)") {
                rows.wrappedValue.append(Entry(value: ""))
            }
        }
    }

    private var birthdaySection: some View {
        Section("Birthday") {
            if let birthday = fields.birthday {
                let monthNames = Calendar(identifier: .gregorian).monthSymbols
                Picker("Month", selection: Binding(
                    get: { birthday.month },
                    set: { fields.birthday = MonthDay(month: $0, day: min(birthday.day, days(in: $0))) }
                )) {
                    ForEach(1...12, id: \.self) { month in
                        Text(monthNames[month - 1]).tag(month)
                    }
                }
                Picker("Day", selection: Binding(
                    get: { birthday.day },
                    set: { fields.birthday = MonthDay(month: birthday.month, day: $0) }
                )) {
                    ForEach(1...days(in: birthday.month), id: \.self) { day in
                        Text(day, format: .number).tag(day)
                    }
                }
                Button("Remove Birthday", role: .destructive) { fields.birthday = nil }
            } else {
                Button("Add Birthday") { fields.birthday = MonthDay(month: 1, day: 1) }
            }
        }
    }

    private func days(in month: Int) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: DateComponents(year: 2000, month: month, day: 1)) else { return 31 }
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 31
    }

    private func save() {
        do {
            try viewModel.saveContact(editedFields, replacing: original)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private struct Entry: Identifiable {
        let id = UUID()
        var value: String
    }
}
