import Foundation
import Testing
@testable import Ebb

@Suite("Reminder scheduler")
struct ReminderSchedulerTests {
    @Test func pausesWhenMigraineLoggedTodayWithoutFullRelief() {
        let preferences = ReminderPreferences(defaults: makeDefaults())
        let entry = SymptomEntry(
            timestamp: .now,
            schemaVersion: "test",
            fieldValues: ["migraine_present": .boolean(true)]
        )
        #expect(
            ReminderScheduler.shouldPauseReminders(
                entries: [entry],
                preferences: preferences
            )
        )
    }

    @Test func doesNotPauseWhenFullReliefLogged() {
        let preferences = ReminderPreferences(defaults: makeDefaults())
        let entry = SymptomEntry(
            timestamp: .now,
            schemaVersion: "test",
            fieldValues: [
                "migraine_present": .boolean(true),
                "relief_effect": .choice("full"),
            ]
        )
        #expect(
            !ReminderScheduler.shouldPauseReminders(
                entries: [entry],
                preferences: preferences
            )
        )
    }

    @Test func nextLutealStartUsesUpcomingCycleDay() throws {
        let calendar = Calendar.ebbCalendar
        let periodStart = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)))
        let overlay = CalendarCycleOverlay(
            calendar: calendar,
            cycleLength: 28,
            periodLength: 5,
            anchorPeriodStart: periodStart
        )
        let reference = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 5)))
        let lutealStart = try #require(overlay.nextLutealStart(from: reference))
        let expected = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15)))
        #expect(calendar.isDate(lutealStart, inSameDayAs: expected))
    }

    @Test func nextLutealStartRollsToNextCycleAfterCurrentWindow() throws {
        let calendar = Calendar.ebbCalendar
        let periodStart = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)))
        let overlay = CalendarCycleOverlay(
            calendar: calendar,
            cycleLength: 28,
            periodLength: 5,
            anchorPeriodStart: periodStart
        )
        let reference = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 20)))
        let lutealStart = try #require(overlay.nextLutealStart(from: reference))
        let expected = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 13)))
        #expect(calendar.isDate(lutealStart, inSameDayAs: expected))
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "ReminderSchedulerTests.\(UUID().uuidString)")!
    }
}

@Suite("Medication preferences")
struct MedicationPreferencesTests {
    @Test func savesAndRestoresReliefKeys() {
        let defaults = UserDefaults(suiteName: "MedicationPreferencesTests.\(UUID().uuidString)")!
        let preferences = MedicationPreferences(defaults: defaults)
        preferences.setSaved("ibuprofen", isSaved: true)
        preferences.setSaved("triptan", isSaved: true)
        preferences.setSaved("ibuprofen", isSaved: false)

        let reloaded = MedicationPreferences(defaults: defaults)
        #expect(reloaded.savedReliefKeys == ["triptan"])
    }
}

@Suite("Onboarding preferences")
struct OnboardingPreferencesTests {
    @Test func marksCompletedInDefaults() {
        let defaults = UserDefaults(suiteName: "OnboardingPreferencesTests.\(UUID().uuidString)")!
        let preferences = OnboardingPreferences(defaults: defaults)
        preferences.markCompleted()
        #expect(defaults.bool(forKey: "ebb.onboarding.completed"))
        let reloaded = OnboardingPreferences(defaults: defaults)
        #expect(reloaded.hasCompletedOnboarding)
    }
}
