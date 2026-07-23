import Foundation
import Testing
@testable import Ebb

@Suite("History access policy")
struct HistoryAccessPolicyTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func bleedingEntry(on day: Date) -> SymptomEntry {
        SymptomEntry(
            timestamp: day,
            schemaVersion: "test",
            fieldValues: ["bleeding": .choice("medium")]
        )
    }

    @Test func premiumHasUnlimitedHistory() {
        let overlay = CalendarCycleOverlay.build(
            from: [bleedingEntry(on: date(2026, 1, 1))],
            calendar: calendar,
            cycleLength: 28
        )
        let ancient = date(2020, 1, 1)
        #expect(
            HistoryAccessPolicy.isDateAccessible(
                ancient,
                overlay: overlay,
                now: date(2026, 6, 15),
                isPremium: true
            )
        )
        #expect(HistoryAccessPolicy.earliestAccessiblePeriodStart(
            overlay: overlay,
            now: date(2026, 6, 15),
            isPremium: true
        ) == nil)
    }

    @Test func freeTierCoversThreeCycles() {
        let junePeriod = date(2026, 6, 1)
        let overlay = CalendarCycleOverlay.build(
            from: [bleedingEntry(on: junePeriod)],
            calendar: calendar,
            cycleLength: 28
        )
        let now = date(2026, 6, 20)

        let earliest = HistoryAccessPolicy.earliestAccessiblePeriodStart(
            overlay: overlay,
            now: now,
            isPremium: false
        )
        #expect(earliest == date(2026, 4, 6))

        #expect(HistoryAccessPolicy.isDateAccessible(
            date(2026, 4, 6),
            overlay: overlay,
            now: now,
            isPremium: false
        ))
        #expect(!HistoryAccessPolicy.isDateAccessible(
            date(2026, 4, 5),
            overlay: overlay,
            now: now,
            isPremium: false
        ))
    }

    @Test func freeTierAllowsAllDatesWithoutCycleAnchor() {
        let overlay = CalendarCycleOverlay(calendar: calendar)
        #expect(HistoryAccessPolicy.isDateAccessible(
            date(2020, 1, 1),
            overlay: overlay,
            isPremium: false
        ))
    }
}

@Suite("Theme preferences")
struct ThemePreferencesTests {
    @Test func defaultThemeIsPlumEmber() {
        let defaults = UserDefaults(suiteName: "ThemePreferencesTests.default")!
        defaults.removePersistentDomain(forName: "ThemePreferencesTests.default")
        let preferences = ThemePreferences(defaults: defaults)
        #expect(preferences.selectedThemeID == Theme.plumEmber.id)
        #expect(preferences.effectiveTheme(isEbbPlus: false) == .plumEmber)
    }

    @Test func premiumThemeRequiresEbbPlus() {
        let defaults = UserDefaults(suiteName: "ThemePreferencesTests.premium")!
        defaults.removePersistentDomain(forName: "ThemePreferencesTests.premium")
        let preferences = ThemePreferences(defaults: defaults)

        #expect(!preferences.canUse(.nocturne, isEbbPlus: false))
        #expect(preferences.select(.nocturne, isEbbPlus: false) == false)
        #expect(preferences.effectiveTheme(isEbbPlus: false) == .plumEmber)

        #expect(preferences.select(.nocturne, isEbbPlus: true))
        #expect(preferences.effectiveTheme(isEbbPlus: true) == .nocturne)
        #expect(preferences.effectiveTheme(isEbbPlus: false) == .plumEmber)
    }
}
