import Contacts
import ContactsUI
import Domain
import SwiftUI
import UIKit

struct ContactListView: View {
    let viewModel: ContactListViewModel
    @Environment(\.openURL) private var openURL
    @State private var searchDraft = ""
    @State private var isAddingContact = false
    @State private var isShowingContactAccess = false
    @State private var isShowingFilters = false
    @State private var isShowingReminders = false

    var body: some View {
        ZStack { content }
            .navigationTitle("Contacts")
            .searchable(text: $searchDraft, prompt: Text("Who did you meet this week?"))
            .task(id: searchDraft) { [searchDraft] in
                if !searchDraft.isEmpty {
                    do {
                        try await Task.sleep(for: .milliseconds(300))
                    } catch {
                        return
                    }
                }
                guard !Task.isCancelled else { return }
                viewModel.setSearchText(searchDraft)
            }
            .onSubmit(of: .search) {
                viewModel.setSearchText(searchDraft)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    sortMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        if viewModel.isLoaded && viewModel.canEditAddressBook {
                            Button {
                                isAddingContact = true
                            } label: {
                                Label("Add Contact", systemImage: "plus")
                            }
                        }
                        if #available(iOS 18, *), viewModel.usesSystemContacts, CNContactStore.authorizationStatus(for: .contacts) == .limited {
                            Button {
                                isShowingContactAccess = true
                            } label: {
                                Label("Manage Contact Access", systemImage: "person.crop.circle.badge.plus")
                            }
                        }
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
            .sheet(isPresented: $isAddingContact) {
                ContactCardEditor(viewModel: viewModel)
            }
            .modifier(ContactAccessPicker(isPresented: $isShowingContactAccess, viewModel: viewModel))
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
                .contactActionAlert(viewModel: viewModel)
            }
            .navigationDestination(for: Contact.self) { contact in
                ContactDetailView(contact: contact, viewModel: viewModel)
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.lastLoggedInteraction != nil {
                    Button("Undo Touchpoint", action: viewModel.undoLastTouchpoint)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.bar)
                }
            }
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.isLoaded {
            if let error = viewModel.loadError {
                ContentUnavailableView {
                    Label("Couldn’t load contacts", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    if error is ContactAccessError, let url = URL(string: UIApplication.openSettingsURLString) {
                        Button("Open Settings") { openURL(url) }
                    }
                    Button("Try Again") { Task { await viewModel.load() } }
                }
            } else {
                ProgressView("Loading contacts…")
            }
        } else if viewModel.allContacts.isEmpty {
            ContentUnavailableView(
                "No contacts available",
                systemImage: "person.crop.circle.badge.questionmark",
                description: Text("Add a contact in Apple Contacts or check BetterContacts’ access in Settings.")
            )
        } else {
            resultsList
        }
    }

    private var resultsList: some View {
        List(viewModel.visibleContacts) { contact in
            NavigationLink(value: contact) {
                ContactRow(contact: contact, viewModel: viewModel)
            }
            .swipeActions(allowsFullSwipe: false) {
                Button {
                    viewModel.logInteraction(contact, kind: .metInPerson)
                } label: {
                    Label("Met", systemImage: "hand.wave")
                }
                .tint(.green)
            }
        }
        .overlay {
            if viewModel.visibleContacts.isEmpty {
                ContentUnavailableView {
                    Label("No matching contacts", systemImage: "person.2.slash")
                } description: {
                    Text("Try a different search or clear your filters.")
                } actions: {
                    Button("Clear Search and Filters") {
                        searchDraft = ""
                        viewModel.setSearchText("")
                        viewModel.setFilter(ContactFilter())
                    }
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

private struct ContactAccessPicker: ViewModifier {
    @Binding var isPresented: Bool
    let viewModel: ContactListViewModel

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.contactAccessPicker(isPresented: $isPresented) { _ in
                Task { await viewModel.load() }
            }
        } else {
            content
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
