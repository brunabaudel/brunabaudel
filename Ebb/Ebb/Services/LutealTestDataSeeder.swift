import Foundation
import SwiftData

/// Inserts backdated bleeding logs so today lands on luteal day 15 (DEBUG / testing).
enum LutealTestDataSeeder {
    static let periodStartDaysAgo = 14
    static let seededPeriodLength = 5

    struct SeedResult: Equatable, Sendable {
        let periodStart: Date
        let cycleDayToday: Int
        let phaseToday: CyclePhase
        let nextLutealStart: Date
    }

    @MainActor
    static func seed(
        schemaVersion: String,
        modelContext: ModelContext,
        cycleService: CycleService,
        calendar: Calendar = .ebbCalendar
    ) throws -> SeedResult {
        let today = calendar.startOfDay(for: .now)
        guard let periodStart = calendar.date(byAdding: .day, value: -periodStartDaysAgo, to: today) else {
            throw SeedError.invalidCalendar
        }

        for dayOffset in 0..<seededPeriodLength {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: periodStart) else { continue }
            let timestamp = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
            let entry = SymptomEntry(
                timestamp: timestamp,
                schemaVersion: schemaVersion,
                fieldValues: ["bleeding": .choice("medium")],
                cyclePhase: .menstrual
            )
            modelContext.insert(entry)
        }

        try modelContext.save()

        let updatedEntries = try modelContext.fetch(FetchDescriptor<SymptomEntry>())
        let overlay = cycleService.makeOverlay(from: updatedEntries)
        guard let cycleDay = overlay.cycleDay(for: .now),
              let phase = overlay.phase(for: .now),
              let nextLuteal = overlay.nextLutealStart(from: .now)
        else {
            throw SeedError.overlayUnavailable
        }

        return SeedResult(
            periodStart: periodStart,
            cycleDayToday: cycleDay,
            phaseToday: phase,
            nextLutealStart: nextLuteal
        )
    }

    enum SeedError: LocalizedError {
        case invalidCalendar
        case overlayUnavailable

        var errorDescription: String? {
            switch self {
            case .invalidCalendar:
                "Could not compute the mock period start date."
            case .overlayUnavailable:
                "Mock period was saved, but cycle data did not resolve. Check Today for the cycle ring."
            }
        }
    }
}
