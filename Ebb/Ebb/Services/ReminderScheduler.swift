import Foundation
import UserNotifications

/// Schedules luteal-window and daily log local notifications (build-plan Phase 9).
enum ReminderScheduler {
    static let lutealNotificationID = "ebb.reminder.luteal"
    static let dailyLogNotificationID = "ebb.reminder.dailyLog"

    struct ScheduleInput {
        let preferences: ReminderPreferences
        let overlay: CalendarCycleOverlay
        let entries: [SymptomEntry]
        let now: Date
    }

    /// Whether reminders should stay quiet while a migraine is active.
    static func shouldPauseReminders(
        entries: [SymptomEntry],
        preferences: ReminderPreferences,
        now: Date = .now,
        calendar: Calendar = .ebbCalendar
    ) -> Bool {
        guard preferences.pauseDuringMigraine else { return false }
        return hasActiveMigraine(entries: entries, now: now, calendar: calendar)
    }

    static func hasActiveMigraine(
        entries: [SymptomEntry],
        now: Date = .now,
        calendar: Calendar = .ebbCalendar
    ) -> Bool {
        let today = calendar.startOfDay(for: now)
        let recent = entries
            .filter { calendar.startOfDay(for: $0.timestamp) == today }
            .filter { $0.fieldValues["migraine_present"] == .boolean(true) }
            .sorted { $0.timestamp > $1.timestamp }

        guard let latest = recent.first else { return false }

        if case .choice("full") = latest.fieldValues["relief_effect"] {
            return false
        }
        return true
    }

    static func nextLutealNotificationDate(
        overlay: CalendarCycleOverlay,
        from now: Date = .now
    ) -> Date? {
        overlay.nextLutealStart(from: now)
    }

    @MainActor
    static func reschedule(input: ScheduleInput) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            lutealNotificationID,
            dailyLogNotificationID,
        ])

        guard !shouldPauseReminders(
            entries: input.entries,
            preferences: input.preferences,
            now: input.now
        ) else {
            return
        }

        if input.preferences.lutealNudgeEnabled,
           let lutealDate = nextLutealNotificationDate(overlay: input.overlay, from: input.now) {
            let calendar = input.overlay.calendar
            let fireComponents = dateComponents(
                on: lutealDate,
                hour: input.preferences.reminderHour,
                minute: input.preferences.reminderMinute,
                calendar: calendar
            )
            if let fireDate = calendar.date(from: fireComponents), fireDate > input.now {
                let content = UNMutableNotificationContent()
                content.title = "Luteal phase starting"
                content.body = "Your higher-risk window is beginning. A quick log helps you spot patterns."
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: fireComponents, repeats: false)
                let request = UNNotificationRequest(
                    identifier: lutealNotificationID,
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)
            }
        }

        if input.preferences.dailyLogReminderEnabled {
            var components = DateComponents()
            components.hour = input.preferences.reminderHour
            components.minute = input.preferences.reminderMinute

            let content = UNMutableNotificationContent()
            content.title = "Time to log"
            content.body = "A quick check-in keeps your migraine and cycle picture up to date."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: dailyLogNotificationID,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: - Private

    private static func dateComponents(
        on day: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> DateComponents {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        return components
    }
}

extension CalendarCycleOverlay {
    /// Start-of-day for the next luteal-window heads-up (day 15 of the cycle).
    func nextLutealStart(from date: Date = .now) -> Date? {
        guard anchorPeriodStart != nil else { return nil }

        let today = calendar.startOfDay(for: date)
        guard let periodStart = periodStart(containing: date) else { return nil }

        if let currentLuteal = calendar.date(byAdding: .day, value: 14, to: periodStart) {
            let lutealDay = calendar.startOfDay(for: currentLuteal)
            if lutealDay >= today {
                return lutealDay
            }
        }

        guard let nextPeriod = calendar.date(byAdding: .day, value: cycleLength, to: periodStart),
              let nextLuteal = calendar.date(byAdding: .day, value: 14, to: nextPeriod)
        else { return nil }

        return calendar.startOfDay(for: nextLuteal)
    }
}
