import Domain
import SwiftUI
import UniformTypeIdentifiers

struct ContactDetailView: View {
    let contact: Contact
    let viewModel: ContactListViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var isEditingContact = false
    @State private var isShowingSystemCard = false
    @State private var isConfirmingDelete = false
    @State private var tagsText: String = ""
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var isCloseCircle: Bool = false
    @State private var isAddingTouchpoint = false
    @State private var editingTouchpoint: Interaction?

    /// The list may have fresher state for this contact than the snapshot the
    /// view was opened with; always render the current copy.
    private var liveContact: Contact {
        viewModel.currentContact(contact)
    }

    var body: some View {
        Form {
            interactionsSection
            closeCircleSection
            phonesSection
            emailsSection
            detailsSection
            birthdaySection
        }
        .navigationTitle(liveContact.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Save", action: save)
                    .accessibilityLabel("Save Relationship Details")
                if viewModel.canEditAddressBook {
                    contactActions
                }
            }
        }
        .onAppear(perform: loadEditableState)
        .sheet(isPresented: $isEditingContact) {
            ContactCardEditor(viewModel: viewModel, contact: liveContact)
        }
        .sheet(isPresented: $isShowingSystemCard) {
            SystemContactCard(contactID: contact.id)
        }
        .onChange(of: viewModel.allContacts.contains { $0.id == contact.id }) { _, exists in
            if !exists { dismiss() }
        }
        .alert("Delete \(liveContact.displayName)?", isPresented: $isConfirmingDelete) {
            Button("Delete Contact", role: .destructive) {
                if viewModel.deleteContact(liveContact) { dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the contact from your address book and any devices that sync with that account.")
        }
        .sheet(isPresented: $isAddingTouchpoint) {
            TouchpointEditor(contact: liveContact, viewModel: viewModel)
        }
        .sheet(item: $editingTouchpoint) { entry in
            TouchpointEditor(contact: liveContact, viewModel: viewModel, interaction: entry)
        }
    }

    private var contactActions: some View {
        Menu {
            Button("Edit Contact", systemImage: "pencil") { isEditingContact = true }
            if viewModel.usesSystemContacts {
                Button("Full Contact Card", systemImage: "person.text.rectangle") {
                    isShowingSystemCard = true
                }
            }
            ShareLink(
                item: SharedContactCard(fields: ContactCardFields(contact: liveContact)),
                preview: SharePreview(liveContact.displayName, image: Image(systemName: "person.crop.circle"))
            ) {
                Label("Share Contact", systemImage: "square.and.arrow.up")
            }
            Button("Delete Contact", systemImage: "trash", role: .destructive) {
                isConfirmingDelete = true
            }
        } label: {
            Label("Contact Actions", systemImage: "ellipsis.circle")
        }
    }

    private var closeCircleSection: some View {
        Section {
            Toggle("Close circle", isOn: $isCloseCircle)
        } footer: {
            Text("Close-circle contacts get more frequent touchpoint reminders.")
        }
    }

    private var phonesSection: some View {
        Section("Phone") {
            if liveContact.phoneNumbers.isEmpty {
                Text("No phone number").foregroundStyle(.secondary)
            } else {
                ForEach(liveContact.phoneNumbers.indices, id: \.self) { index in
                    let number = liveContact.phoneNumbers[index]
                    HStack {
                        if let url = URL(string: "tel:" + number.filter { !$0.isWhitespace }) {
                            Link(destination: url) {
                                Label(number, systemImage: "phone")
                            }
                        } else {
                            Label(number, systemImage: "phone")
                        }
                        Spacer()
                        if let url = URL(string: "sms:" + number.filter { !$0.isWhitespace }) {
                            Link(destination: url) {
                                Image(systemName: "message")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Message \(number)")
                        }
                    }
                }
            }
        }
    }

    private var emailsSection: some View {
        Section("Email") {
            if liveContact.emailAddresses.isEmpty {
                Text("No email address").foregroundStyle(.secondary)
            } else {
                ForEach(liveContact.emailAddresses, id: \.self) { address in
                    if let url = URL(string: "mailto:" + address) {
                        Link(destination: url) {
                            Label(address, systemImage: "envelope")
                        }
                    } else {
                        Label(address, systemImage: "envelope")
                    }
                }
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            if let organization = liveContact.organization, !organization.isEmpty {
                LabeledContent("Organization", value: organization)
            }
            TextField("Location, e.g. Berlin", text: $location)
            TextField("Tags, comma separated", text: $tagsText)
            TextField("Private notes", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var birthdaySection: some View {
        Section("Birthday") {
            if let birthday = liveContact.birthday {
                LabeledContent("Birthday", value: birthdayLabel(for: birthday))
            } else {
                Text("No birthday saved").foregroundStyle(.secondary)
            }
        }
    }

    private var interactionsSection: some View {
        Section("Touchpoints") {
            Menu {
                ForEach(InteractionKind.allCases, id: \.self) { kind in
                    Button(kind.displayName) {
                        viewModel.logInteraction(liveContact, kind: kind)
                    }
                }
                Divider()
                Button("Choose date and note") { isAddingTouchpoint = true }
            } label: {
                Label("Log an interaction", systemImage: "square.and.pencil")
            }

            if viewModel.lastLoggedInteraction?.contactID == contact.id {
                Button("Undo Touchpoint", action: viewModel.undoLastTouchpoint)
            }

            let interactions = viewModel.interactions(for: liveContact)
            if interactions.isEmpty {
                Text("Nothing logged yet.").foregroundStyle(.secondary)
            } else {
                ForEach(interactions, content: interactionRow)
            }
        }
    }

    private func interactionRow(_ interaction: Interaction) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(interaction.kind.displayName)
                    .font(.subheadline)
                Text(viewModel.touchpointDateLabel(interaction.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let note = interaction.note {
                    Text(note).font(.caption)
                }
            }
            Spacer()
            Button {
                editingTouchpoint = interaction
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Edit \(interaction.kind.displayName) touchpoint")
        }
    }

    private func birthdayLabel(for birthday: MonthDay) -> String {
        let calendar = Calendar.current
        let thisYear = calendar.component(.year, from: Date())
        let date = calendar.date(from: DateComponents(year: thisYear, month: birthday.month, day: birthday.day)) ?? Date()
        var label = date.formatted(.dateTime.month().day())
        if let days = viewModel.daysUntilBirthday(of: liveContact) {
            if days == 0 {
                label += " · today"
            } else if days == 1 {
                label += " · tomorrow"
            } else {
                label += " · in \(days) days"
            }
        }
        return label
    }

    private func loadEditableState() {
        tagsText = liveContact.tags.sorted().joined(separator: ", ")
        location = liveContact.location ?? ""
        notes = liveContact.notes
        isCloseCircle = liveContact.isCloseCircle
    }

    private func save() {
        let parsedTags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
        viewModel.saveAnnotations(
            ContactAnnotations(
                tags: Set(parsedTags),
                location: trimmedLocation.isEmpty ? nil : trimmedLocation,
                notes: notes,
                isCloseCircle: isCloseCircle
            ),
            for: contact.id
        )
    }
}

private struct SharedContactCard: Transferable {
    let fields: ContactCardFields

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .vCard) { try $0.fields.vCard() }
            .suggestedFileName { _ in "Contact.vcf" }
    }
}
