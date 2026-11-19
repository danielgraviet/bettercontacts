import Domain
import SwiftUI

struct ContactDetailView: View {
    let contact: Contact
    let viewModel: ContactListViewModel

    @State private var tagsText: String = ""
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var isCloseCircle: Bool = false
    @State private var interactions: [Interaction] = []

    /// The list may have fresher state for this contact than the snapshot the
    /// view was opened with; always render the current copy.
    private var liveContact: Contact {
        viewModel.currentContact(contact)
    }

    var body: some View {
        Form {
            closeCircleSection
            phonesSection
            emailsSection
            detailsSection
            birthdaySection
            interactionsSection
        }
        .navigationTitle(liveContact.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save", action: save)
            }
        }
        .onAppear(perform: loadEditableState)
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
                ForEach(liveContact.phoneNumbers, id: \.self) { number in
                    if let url = URL(string: "tel:" + number.filter { !$0.isWhitespace }) {
                        Link(destination: url) {
                            Label(number, systemImage: "phone")
                        }
                    } else {
                        Label(number, systemImage: "phone")
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
            TextField("Notes", text: $notes, axis: .vertical)
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
                        interactions = viewModel.interactions(for: liveContact)
                    }
                }
            } label: {
                Label("Log an interaction", systemImage: "square.and.pencil")
            }
            if interactions.isEmpty {
                Text("Nothing logged yet.").foregroundStyle(.secondary)
            } else {
                ForEach(interactions) { interaction in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(interaction.kind.displayName)
                            .font(.subheadline)
                        Text(interaction.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let note = interaction.note {
                            Text(note).font(.caption)
                        }
                    }
                }
            }
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
        interactions = viewModel.interactions(for: liveContact)
    }

    private func save() {
        var updated = liveContact
        let parsedTags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        updated.tags = Set(parsedTags)
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
        updated.location = trimmedLocation.isEmpty ? nil : trimmedLocation
        updated.notes = notes
        updated.isCloseCircle = isCloseCircle
        viewModel.saveChanges(to: updated)
    }
}
