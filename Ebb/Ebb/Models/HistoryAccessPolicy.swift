import Foundation

/// Free-tier history window (~3 cycles). Premium unlocks full calendar history.
enum HistoryAccessPolicy {
    static let freeCycleLimit = 3

    /// Earliest period start a free user may browse, or `nil` when unlimited.
    static func earliestAccessiblePeriodStart(
        overlay: CalendarCycleOverlay,
        now: Date = .now,
        isPremium: Bool
    ) -> Date? {
        guard !isPremium else { return nil }
        guard let currentStart = overlay.periodStart(containing: now) else { return nil }

        var start = currentStart
        for _ in 1..<freeCycleLimit {
            guard let previous = overlay.calendar.date(
                byAdding: .day,
                value: -overlay.cycleLength,
                to: start
            ) else { break }
            start = previous
        }
        return start
    }

    static func isDateAccessible(
        _ date: Date,
        overlay: CalendarCycleOverlay,
        now: Date = .now,
        isPremium: Bool
    ) -> Bool {
        guard !isPremium else { return true }
        guard let earliest = earliestAccessiblePeriodStart(
            overlay: overlay,
            now: now,
            isPremium: false
        ) else { return true }
        return overlay.calendar.startOfDay(for: date) >= earliest
    }

    static func isMonthAccessible(
        _ month: Date,
        overlay: CalendarCycleOverlay,
        now: Date = .now,
        isPremium: Bool
    ) -> Bool {
        let calendar = overlay.calendar
        guard let monthEnd = calendar.date(
            byAdding: DateComponents(month: 1, day: -1),
            to: calendar.startOfMonth(for: month)
        ) else { return true }
        return isDateAccessible(monthEnd, overlay: overlay, now: now, isPremium: isPremium)
    }

    static func isWeekAccessible(
        weekStart: Date,
        overlay: CalendarCycleOverlay,
        now: Date = .now,
        isPremium: Bool
    ) -> Bool {
        isDateAccessible(weekStart, overlay: overlay, now: now, isPremium: isPremium)
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }
}
