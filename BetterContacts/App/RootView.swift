import Contacts
import Domain
import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var scheduler = NotificationReminderScheduler()
    @State private var viewModel: ContactListViewModel

    init(environment: AppEnvironment) {
        _viewModel = State(
            initialValue: ContactListViewModel(
                repository: environment.repository,
                embedder: environment.embedder,
                calendar: environment.calendar,
                addressBook: environment.addressBook,
                usesSystemContacts: environment.usesSystemContacts,
                now: environment.now
            )
        )
    }

    var body: some View {
        let plan = ReminderNotificationPlan(reminders: viewModel.reminders, snoozes: viewModel.activeSnoozes)
        let nextExpiry = plan.snoozes.values.min()
        NavigationStack {
            ContactListView(viewModel: viewModel)
        }
        .contactActionAlert(viewModel: viewModel)
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            viewModel.refreshForCurrentTime()
            if viewModel.usesSystemContacts { Task { await viewModel.load() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .CNContactStoreDidChange)) { _ in
            if viewModel.usesSystemContacts { Task { await viewModel.load() } }
        }
        .task(id: nextExpiry) {
            guard let nextExpiry else { return }
            let delay = max(0, nextExpiry.timeIntervalSince(viewModel.currentDate))
            do {
                try await Task.sleep(for: .seconds(delay))
                viewModel.refreshForCurrentTime()
            } catch {
                // The next snooze expiration changed while this task was waiting.
            }
        }
        .task(id: plan) {
            guard viewModel.isLoaded, await scheduler.isAuthorized() else { return }
            await scheduler.syncReminders(plan.reminders, now: viewModel.currentDate, calendar: .current, snoozes: plan.snoozes)
        }
    }
}

private struct ReminderNotificationPlan: Equatable {
    let reminders: [SmartReminder]
    let snoozes: [String: Date]
}

extension View {
    func contactActionAlert(viewModel: ContactListViewModel) -> some View {
        alert(
            "Contact Update Failed",
            isPresented: Binding(
                get: { viewModel.actionError != nil },
                set: { if !$0 { viewModel.actionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.actionError ?? "")
        }
    }
}
