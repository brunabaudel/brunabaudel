import Foundation
import HealthKit
import Observation

struct CycleSnapshot: Equatable, Sendable {
    let phase: CyclePhase?
    let cycleDay: Int?
    let cycleLength: Int
    let daysUntilNextPeriod: Int?
    let summary: String
    let hasCycleData: Bool
}

/// HealthKit reads + cycle-phase derivation (build-plan `CycleService`).
@Observable
@MainActor
final class CycleService {
    private(set) var authorizationStatus: CycleAuthStatus = .unavailable
    private(set) var healthKitPeriodDays: Set<Date> = []
    private(set) var lastRefreshed: Date?

    let preferences: CyclePreferences

    private let provider: any CycleDataProvider
    private let calendar: Calendar
    private var refreshTask: Task<Void, Never>?

    init(
        preferences: CyclePreferences = CyclePreferences(),
        provider: (any CycleDataProvider)? = nil,
        calendar: Calendar = .ebbCalendar
    ) {
        self.preferences = preferences
        self.calendar = calendar
        if let provider {
            self.provider = provider
        } else if HKHealthStore.isHealthDataAvailable() {
            self.provider = HealthKitCycleDataProvider()
        } else {
            self.provider = MockCycleDataProvider(status: .unavailable)
        }
    }

    func refresh() async {
        if let refreshTask {
            await refreshTask.value
            return
        }

        let task = Task { @MainActor in
            await performRefresh()
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    func requestAuthorization() async {
        guard provider.isAvailable else {
            authorizationStatus = .unavailable
            return
        }

        do {
            try await provider.requestAuthorization()
        } catch {
            // Still refresh — the user may have partially enabled data in the sheet.
        }
        await refresh()
    }

    private func performRefresh() async {
        authorizationStatus = await provider.resolveAuthorizationStatus(calendar: calendar)

        guard authorizationStatus == .authorized else {
            healthKitPeriodDays = []
            lastRefreshed = Date.now
            return
        }

        do {
            healthKitPeriodDays = try await provider.fetchMenstrualFlowDays(calendar: calendar)
            lastRefreshed = Date.now
        } catch {
            healthKitPeriodDays = []
        }
    }

    func makeOverlay(
        from entries: [SymptomEntry],
        extraPeriodDays: Set<Date> = []
    ) -> CalendarCycleOverlay {
        CalendarCycleOverlay.build(
            from: entries,
            healthKitPeriodDays: healthKitPeriodDays.union(extraPeriodDays),
            calendar: calendar,
            cycleLength: preferences.typicalCycleLength,
            periodLength: preferences.periodLength
        )
    }

    func phase(
        for date: Date,
        entries: [SymptomEntry] = [],
        extraPeriodDays: Set<Date> = []
    ) -> CyclePhase? {
        makeOverlay(from: entries, extraPeriodDays: extraPeriodDays).phase(for: date)
    }

    func snapshot(for date: Date, entries: [SymptomEntry]) -> CycleSnapshot {
        let overlay = makeOverlay(from: entries)
        let phase = overlay.phase(for: date)
        let cycleDay = overlay.cycleDay(for: date)
        let daysToPeriod = overlay.daysUntilNextPeriod(from: date)
        let hasData = overlay.anchorPeriodStart != nil

        let summary: String
        if let phase {
            summary = phase.ringSummary(daysUntilNextPeriod: daysToPeriod)
        } else if authorizationStatus == .notDetermined {
            summary = "Connect HealthKit in Settings to tag entries with your cycle phase."
        } else if authorizationStatus == .denied {
            summary = "Turn on Menstrual Cycle for Ebb in the Health app, or log bleeding when you tap."
        } else {
            summary = "Log bleeding or connect HealthKit to see your cycle phase."
        }

        return CycleSnapshot(
            phase: phase,
            cycleDay: cycleDay,
            cycleLength: preferences.typicalCycleLength,
            daysUntilNextPeriod: daysToPeriod,
            summary: summary,
            hasCycleData: hasData
        )
    }
}

extension CyclePhase {
    func ringSummary(daysUntilNextPeriod: Int?) -> String {
        switch self {
        case .menstrual:
            return "Menstrual phase — take it gently if migraines flare with bleeding."
        case .follicular:
            return "Follicular phase — estrogen is rising."
        case .ovulation:
            return "Ovulation window — some people feel a brief headache shift here."
        case .luteal:
            if let days = daysUntilNextPeriod, days > 0 {
                let dayLabel = days == 1 ? "day" : "days"
                return "Luteal phase — period likely in \(days) \(dayLabel). A common window for hormonal migraines."
            }
            return "Luteal phase — a common window for hormonal migraines."
        }
    }
}

