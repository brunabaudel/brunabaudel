import Foundation
import Testing
@testable import Ebb

@Suite("Calendar cycle overlay")
struct CalendarCycleOverlayTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func entry(on day: Date, bleeding: String? = nil, migraine: Bool = false) -> SymptomEntry {
        var values: [String: FieldValue] = [:]
        if let bleeding {
            values["bleeding"] = .choice(bleeding)
        }
        if migraine {
            values["migraine_present"] = .boolean(true)
        }
        return SymptomEntry(
            timestamp: day,
            schemaVersion: "test",
            fieldValues: values
        )
    }

    @Test func detectsLoggedPeriodCluster() {
        let entries = [
            entry(on: date(2026, 6, 20), bleeding: "light"),
            entry(on: date(2026, 6, 21), bleeding: "medium"),
            entry(on: date(2026, 6, 22), bleeding: "heavy"),
        ]
        let overlay = CalendarCycleOverlay.build(from: entries, calendar: calendar)

        #expect(overlay.isLoggedPeriod(date(2026, 6, 20)))
        #expect(overlay.isLoggedPeriod(date(2026, 6, 21)))
        #expect(overlay.isLoggedPeriod(date(2026, 6, 22)))
        #expect(!overlay.isLoggedPeriod(date(2026, 6, 23)))
        #expect(overlay.anchorPeriodStart == date(2026, 6, 20))
    }

    @Test func ignoresNoneBleeding() {
        let entries = [entry(on: date(2026, 6, 10), bleeding: "none")]
        let overlay = CalendarCycleOverlay.build(from: entries, calendar: calendar)
        #expect(overlay.loggedPeriodDays.isEmpty)
        #expect(overlay.anchorPeriodStart == nil)
    }

    @Test func mergesHealthKitFlowDaysWithEntries() {
        let entries = [entry(on: date(2026, 6, 14), bleeding: "medium")]
        let healthKitDays: Set<Date> = [
            date(2026, 6, 1),
            date(2026, 6, 2),
            date(2026, 6, 3),
        ]
        let overlay = CalendarCycleOverlay.build(
            from: entries,
            healthKitPeriodDays: healthKitDays,
            calendar: calendar
        )

        #expect(overlay.isLoggedPeriod(date(2026, 6, 1)))
        #expect(overlay.isLoggedPeriod(date(2026, 6, 14)))
        #expect(overlay.anchorPeriodStart == date(2026, 6, 14))
        #expect(overlay.phase(for: date(2026, 6, 28)) == .luteal)
    }

    @Test func derivesLutealAndPredictedPeriodFromAnchor() {
        let entries = [entry(on: date(2026, 6, 1), bleeding: "medium")]
        let overlay = CalendarCycleOverlay.build(from: entries, calendar: calendar)

        #expect(overlay.cycleDay(for: date(2026, 6, 1)) == 1)
        #expect(overlay.phase(for: date(2026, 6, 15)) == .luteal)
        #expect(overlay.isLuteal(date(2026, 6, 15)))
        #expect(overlay.isPredictedPeriod(date(2026, 6, 29)))
        #expect(!overlay.isPredictedPeriod(date(2026, 6, 15)))
    }

    @Test func daysUntilNextPeriodDuringLuteal() {
        let entries = [entry(on: date(2026, 6, 1), bleeding: "medium")]
        let overlay = CalendarCycleOverlay.build(from: entries, calendar: calendar)
        #expect(overlay.daysUntilNextPeriod(from: date(2026, 6, 24)) == 5)
        #expect(overlay.daysUntilNextPeriod(from: date(2026, 6, 2)) == 0)
    }

    @Test func migraineCountInMonth() {
        let entries = [
            entry(on: date(2026, 6, 8), migraine: true),
            entry(on: date(2026, 6, 11), migraine: true),
            entry(on: date(2026, 7, 1), migraine: true),
        ]
        let overlay = CalendarCycleOverlay.build(from: entries, calendar: calendar)
        #expect(overlay.migraineCount(in: entries, monthContaining: date(2026, 6, 14)) == 2)
    }

    @Test func entriesOnDaySortsNewestFirst() {
        let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date(2026, 6, 14))!
        let evening = calendar.date(bySettingHour: 20, minute: 40, second: 0, of: date(2026, 6, 14))!
        let entries = [
            SymptomEntry(timestamp: morning, schemaVersion: "test"),
            SymptomEntry(timestamp: evening, schemaVersion: "test"),
        ]
        let overlay = CalendarCycleOverlay.build(from: entries, calendar: calendar)
        let dayEntries = overlay.entries(on: date(2026, 6, 14), from: entries)
        #expect(dayEntries.map(\.timestamp) == [evening, morning])
    }
}

@Suite("Cycle service")
struct CycleServiceTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "ebb.cycle.service.tests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    @Test @MainActor func stampsPhaseFromMockHealthKitData() async {
        let periodStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let periodDays = (0..<5).compactMap { calendar.date(byAdding: .day, value: $0, to: periodStart) }
        let provider = MockCycleDataProvider(periodDays: Set(periodDays))
        let preferences = CyclePreferences(defaults: makeDefaults())
        let service = CycleService(
            preferences: preferences,
            provider: provider,
            calendar: calendar
        )

        await service.refresh()

        let target = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        let phase = service.phase(for: target, entries: [])
        #expect(phase == .luteal)
    }

    @Test @MainActor func extraPeriodDaysIncludedWhenSaving() async {
        let provider = MockCycleDataProvider()
        let preferences = CyclePreferences(defaults: makeDefaults())
        let service = CycleService(
            preferences: preferences,
            provider: provider,
            calendar: calendar
        )
        let day = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!

        let phase = service.phase(
            for: day,
            entries: [],
            extraPeriodDays: [calendar.startOfDay(for: day)]
        )
        #expect(phase == .menstrual)
    }
}
