import Domain
import SwiftUI

struct RemindersView: View {
    let viewModel: ContactListViewModel
    @State private var scheduler = NotificationReminderScheduler()
    @State private var notificationsEnabled = false

    var body: some View {
        List {
            Section("Reach out to") {
                if viewModel.overdueTouchpointReminders.isEmpty {
                    Text("Everyone is up to date.").foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.overdueTouchpointReminders) { reminder in
                        NavigationLink(value: reminder.contact) {
                            reminderRow(title: reminder.contact.displayName, detail: touchpointDetail(reminder))
                        }
                    }
                }
            }
            Section("Birthdays") {
                if viewModel.upcomingBirthdayReminders.isEmpty {
                    Text("No birthdays in the next 30 days.").foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.upcomingBirthdayReminders) { reminder in
                        NavigationLink(value: reminder.contact) {
                            reminderRow(title: reminder.contact.displayName, detail: birthdayDetail(reminder))
                        }
                    }
                }
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        if await scheduler.requestAuthorization() {
                            await scheduler.syncReminders(
                                viewModel.reminders,
                                now: Date(),
                                calendar: .current
                            )
                            notificationsEnabled = true
                        }
                    }
                } label: {
                    Label(
                        "Notify me",
                        systemImage: notificationsEnabled ? "bell.badge.fill" : "bell.badge"
                    )
                }
            }
        }
        .navigationDestination(for: Contact.self) { contact in
            ContactDetailView(contact: contact, viewModel: viewModel)
        }
    }

    private func reminderRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).bold()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func touchpointDetail(_ reminder: SmartReminder) -> String {
        guard case let .overdueTouchpoint(daysOverdue) = reminder.reason else { return "" }
        if daysOverdue == 0 { return "Due today" }
        return "\(daysOverdue) day\(daysOverdue == 1 ? "" : "s") overdue"
    }

    private func birthdayDetail(_ reminder: SmartReminder) -> String {
        guard case let .upcomingBirthday(daysUntil) = reminder.reason else { return "" }
        if daysUntil == 0 { return "Birthday today" }
        if daysUntil == 1 { return "Birthday tomorrow" }
        return "Birthday in \(daysUntil) days"
    }
}
