import Foundation
import Observation

/// Local notification toggles and reminder time (build-plan Phase 9).
@Observable
final class ReminderPreferences {
    static let defaultReminderHour = 21
    static let defaultReminderMinute = 0

    var lutealNudgeEnabled: Bool {
        didSet { defaults.set(lutealNudgeEnabled, forKey: Keys.lutealNudge) }
    }

    var dailyLogReminderEnabled: Bool {
        didSet { defaults.set(dailyLogReminderEnabled, forKey: Keys.dailyLog) }
    }

    var pauseDuringMigraine: Bool {
        didSet { defaults.set(pauseDuringMigraine, forKey: Keys.pauseDuringMigraine) }
    }

    var reminderHour: Int {
        didSet { persistReminderTime() }
    }

    var reminderMinute: Int {
        didSet { persistReminderTime() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        lutealNudgeEnabled = defaults.object(forKey: Keys.lutealNudge) as? Bool ?? true
        dailyLogReminderEnabled = defaults.bool(forKey: Keys.dailyLog)
        pauseDuringMigraine = defaults.object(forKey: Keys.pauseDuringMigraine) as? Bool ?? true
        reminderHour = defaults.object(forKey: Keys.reminderHour) as? Int ?? Self.defaultReminderHour
        reminderMinute = defaults.object(forKey: Keys.reminderMinute) as? Int ?? Self.defaultReminderMinute
        reminderHour = Self.clampedHour(reminderHour)
        reminderMinute = Self.clampedMinute(reminderMinute)
    }

    var reminderTimeLabel: String {
        String(format: "%02d:%02d", reminderHour, reminderMinute)
    }

    func resetToDefaults() {
        lutealNudgeEnabled = true
        dailyLogReminderEnabled = false
        pauseDuringMigraine = true
        reminderHour = Self.defaultReminderHour
        reminderMinute = Self.defaultReminderMinute
    }

    // MARK: - Private

    private enum Keys {
        static let lutealNudge = "ebb.reminders.lutealNudge"
        static let dailyLog = "ebb.reminders.dailyLog"
        static let pauseDuringMigraine = "ebb.reminders.pauseDuringMigraine"
        static let reminderHour = "ebb.reminders.hour"
        static let reminderMinute = "ebb.reminders.minute"
    }

    private let defaults: UserDefaults

    private func persistReminderTime() {
        let hour = Self.clampedHour(reminderHour)
        let minute = Self.clampedMinute(reminderMinute)
        if reminderHour != hour { reminderHour = hour; return }
        if reminderMinute != minute { reminderMinute = minute; return }
        defaults.set(reminderHour, forKey: Keys.reminderHour)
        defaults.set(reminderMinute, forKey: Keys.reminderMinute)
    }

    private static func clampedHour(_ value: Int) -> Int {
        min(max(value, 0), 23)
    }

    private static func clampedMinute(_ value: Int) -> Int {
        min(max(value, 0), 59)
    }
}
