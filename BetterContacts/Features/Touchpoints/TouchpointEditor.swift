import Domain
import SwiftUI

struct TouchpointEditor: View {
    let contact: Contact
    let viewModel: ContactListViewModel
    private let original: Interaction?

    @Environment(\.dismiss) private var dismiss
    @State private var kind: InteractionKind
    @State private var date: Date
    @State private var note: String

    init(contact: Contact, viewModel: ContactListViewModel, interaction: Interaction? = nil) {
        self.contact = contact
        self.viewModel = viewModel
        original = interaction
        _kind = State(initialValue: interaction?.kind ?? .metInPerson)
        _date = State(initialValue: interaction?.date ?? viewModel.currentDate)
        _note = State(initialValue: interaction?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) {
                    ForEach(InteractionKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                DatePicker("Date", selection: $date, in: ...latestDate, displayedComponents: .date)
                Button("Yesterday") { date = viewModel.yesterday }
                TextField("Touchpoint note", text: $note)
            }
            .navigationTitle(original == nil ? "Log Touchpoint" : "Edit Touchpoint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Touchpoint", action: save)
                }
            }
        }
        .contactActionAlert(viewModel: viewModel)
    }

    private var latestDate: Date {
        max(original?.date ?? .distantPast, viewModel.currentDate)
    }

    private func save() {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedNote = trimmed.isEmpty ? nil : trimmed
        let saved: Bool
        if let original {
            let updated = Interaction(id: original.id, contactID: contact.id, date: date, kind: kind, note: savedNote)
            saved = viewModel.updateInteraction(updated)
        } else {
            saved = viewModel.logInteraction(contact, kind: kind, date: date, note: savedNote)
        }
        if saved { dismiss() }
    }
}
