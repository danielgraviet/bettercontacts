import Domain
import SwiftUI

struct ContactListView: View {
    let viewModel: ContactListViewModel
    @State private var isShowingFilters = false
    @State private var isShowingReminders = false

    var body: some View {
        content
            .navigationTitle("Contacts")
            .searchable(
                text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.setSearchText($0) }
                ),
                prompt: Text("Who did you meet this week?")
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    sortMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button {
                            isShowingFilters = true
                        } label: {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        }
                        Button {
                            isShowingReminders = true
                        } label: {
                            Label("Reminders", systemImage: "bell")
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingFilters) {
                FilterSheet(filter: Binding(
                    get: { viewModel.filter },
                    set: { viewModel.setFilter($0) }
                ))
            }
            .sheet(isPresented: $isShowingReminders) {
                NavigationStack {
                    RemindersView(viewModel: viewModel)
                }
            }
            .navigationDestination(for: Contact.self) { contact in
                ContactDetailView(contact: contact, viewModel: viewModel)
            }
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.isLoaded && viewModel.errorMessage == nil {
            ProgressView("Loading contacts…")
        } else if let errorMessage = viewModel.errorMessage {
            ContentUnavailableView {
                Label("Couldn't load contacts", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            }
        } else if viewModel.visibleContacts.isEmpty {
            ContentUnavailableView {
                Label("No matching contacts", systemImage: "person.2.slash")
            } description: {
                Text("Try a different search, filter, or sort.")
            }
        } else {
            List(viewModel.visibleContacts) { contact in
                NavigationLink(value: contact) {
                    ContactRow(contact: contact, viewModel: viewModel)
                }
                .swipeActions {
                    Button {
                        viewModel.logInteraction(contact, kind: .metInPerson)
                    } label: {
                        Label("Met", systemImage: "hand.wave")
                    }
                    .tint(.green)
                }
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: Binding(
                get: { viewModel.sort },
                set: { viewModel.setSort($0) }
            )) {
                ForEach(ContactSort.allCases) { sort in
                    Text(sort.displayName).tag(sort)
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }
}

/// One row: name, organization, tags, and quick signals for what needs attention.
struct ContactRow: View {
    let contact: Contact
    let viewModel: ContactListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(contact.displayName)
                    .font(.body)
                    .bold()
                if contact.isCloseCircle {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
                Spacer()
                if viewModel.urgency(for: contact).isDue {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if let days = viewModel.daysUntilBirthday(of: contact), days <= 14 {
                    Image(systemName: "gift.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
            }
            if !contact.tags.isEmpty {
                Text(contact.tags.sorted().joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                if let organization = contact.organization, !organization.isEmpty {
                    Label(organization, systemImage: "building.2")
                }
                if let location = contact.location, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

extension ContactSort {
    /// Labels shown in the sort menu.
    var displayName: String {
        switch self {
        case .alphabetical: return "Name"
        case .soonestBirthday: return "Next birthday"
        case .mostRecentlyInteracted: return "Recently contacted"
        case .mostStaleRelationship: return "Longest since contact"
        }
    }
}
