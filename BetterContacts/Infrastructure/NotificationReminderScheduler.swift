import Domain
import Foundation
import UserNotifications

/// Schedules local notifications for the reminders feed. This is the only
/// part of the app that talks to UserNotifications directly, and it is
/// deliberately thin: there is no logic worth unit testing here, only a
/// system SDK boundary (see TESTING.md for why that is intentional).
@MainActor
final class NotificationReminderScheduler {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    /// Replaces every scheduled reminder notification with the given reminders.
    /// Overdue touchpoints fire at 10am today; birthdays fire at 9am on the day.
    func syncReminders(_ reminders: [SmartReminder], now: Date, calendar: Calendar) async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier))
        for reminder in reminders.prefix(20) {
            try? await center.add(notificationRequest(for: reminder, now: now, calendar: calendar))
        }
    }

    private func notificationRequest(
        for reminder: SmartReminder,
        now: Date,
        calendar: Calendar
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.sound = .default

        var triggerDate = now
        var hour = 10
        switch reminder.reason {
        case let .upcomingBirthday(daysUntil):
            content.title = "\(reminder.contact.displayName)'s birthday"
            content.body = "\(reminder.contact.displayName) has a birthday in \(daysUntil) day\(daysUntil == 1 ? "" : "s")."
            triggerDate = calendar.date(byAdding: .day, value: daysUntil, to: now) ?? now
            hour = 9
        case let .overdueTouchpoint(daysOverdue):
            content.title = "Keep in touch with \(reminder.contact.displayName)"
            if daysOverdue == 0 {
                content.body = "It's time to reach out to \(reminder.contact.displayName)."
            } else {
                content.body = "\(reminder.contact.displayName) is \(daysOverdue) days overdue for a catch-up."
            }
        }

        var components = calendar.dateComponents([.year, .month, .day], from: triggerDate)
        components.hour = hour
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: "reminder-\(reminder.id)", content: content, trigger: trigger)
    }
}
