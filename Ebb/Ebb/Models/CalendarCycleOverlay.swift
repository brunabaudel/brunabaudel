import Foundation

/// Cycle decorations for the calendar until Phase 4's HealthKit-backed
/// `CycleService` exists. Logged bleeding comes from entries; luteal tint
/// and predicted period windows are derived from the most recent logged
/// period start and a default 28-day cycle.
struct CalendarCycleOverlay: Equatable, Sendable {
    let calendar: Calendar
    let cycleLength: Int
    let periodLength: Int
    let loggedPeriodDays: Set<Date>
    /// Start of the most recent logged period cluster (start-of-day).
    let anchorPeriodStart: Date?

    init(
        calendar: Calendar = .current,
        cycleLength: Int = 28,
        periodLength: Int = 5,
        loggedPeriodDays: Set<Date> = [],
        anchorPeriodStart: Date? = nil
    ) {
        self.calendar = calendar
        self.cycleLength = cycleLength
        self.periodLength = periodLength
        self.loggedPeriodDays = loggedPeriodDays
        self.anchorPeriodStart = anchorPeriodStart
    }

    static func build(
        from entries: [SymptomEntry],
        calendar: Calendar = .current,
        cycleLength: Int = 28,
        periodLength: Int = 5
    ) -> CalendarCycleOverlay {
        let loggedDays = Set(
            entries
                .filter(isLoggedBleeding)
                .map { calendar.startOfDay(for: $0.timestamp) }
        )
        let anchor = mostRecentPeriodStart(from: loggedDays, calendar: calendar)
        return CalendarCycleOverlay(
            calendar: calendar,
            cycleLength: cycleLength,
            periodLength: periodLength,
            loggedPeriodDays: loggedDays,
            anchorPeriodStart: anchor
        )
    }

    func cycleDay(for date: Date) -> Int? {
        guard let start = periodStart(containing: date) else { return nil }
        let dayOffset = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day ?? 0
        guard dayOffset >= 0 else { return nil }
        return (dayOffset % cycleLength) + 1
    }

    func phase(for date: Date) -> CyclePhase? {
        guard let day = cycleDay(for: date) else { return nil }
        if day <= periodLength { return .menstrual }
        if day <= 13 { return .follicular }
        if day == 14 { return .ovulation }
        return .luteal
    }

    func isLuteal(_ date: Date) -> Bool {
        phase(for: date) == .luteal
    }

    func isLoggedPeriod(_ date: Date) -> Bool {
        loggedPeriodDays.contains(calendar.startOfDay(for: date))
    }

    func isPredictedPeriod(_ date: Date) -> Bool {
        guard anchorPeriodStart != nil else { return false }
        guard !isLoggedPeriod(date) else { return false }
        guard let day = cycleDay(for: date) else { return false }
        return day <= periodLength
    }

    func daysUntilNextPeriod(from date: Date = .now) -> Int? {
        guard let day = cycleDay(for: date) else { return nil }
        if day <= periodLength { return 0 }
        return cycleLength - day + 1
    }

    func migraineCount(in entries: [SymptomEntry], monthContaining date: Date) -> Int {
        entries.filter { entry in
            calendar.isDate(entry.timestamp, equalTo: date, toGranularity: .month)
                && entry.fieldValues["migraine_present"] == .boolean(true)
        }.count
    }

    func entries(on day: Date, from entries: [SymptomEntry]) -> [SymptomEntry] {
        entries
            .filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Private

    private func periodStart(containing date: Date) -> Date? {
        guard var start = anchorPeriodStart else { return nil }
        let target = calendar.startOfDay(for: date)

        while let previous = calendar.date(byAdding: .day, value: -cycleLength, to: start),
              previous > target {
            start = previous
        }

        while let next = calendar.date(byAdding: .day, value: cycleLength, to: start),
              next <= target {
            start = next
        }

        return start
    }

    private static func isLoggedBleeding(_ entry: SymptomEntry) -> Bool {
        guard case .choice(let key)? = entry.fieldValues["bleeding"] else { return false }
        return key != "none"
    }

    private static func mostRecentPeriodStart(from days: Set<Date>, calendar: Calendar) -> Date? {
        guard let latest = days.max() else { return nil }
        var start = latest
        while let previous = calendar.date(byAdding: .day, value: -1, to: start),
              days.contains(previous) {
            start = previous
        }
        return start
    }
}
