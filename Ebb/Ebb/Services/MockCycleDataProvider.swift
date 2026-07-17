import Foundation

/// Deterministic cycle data for previews, simulator, and unit tests.
struct MockCycleDataProvider: CycleDataProvider {
    var isAvailable: Bool = true
    var status: CycleAuthStatus = .authorized
    var periodDays: Set<Date> = []

    func resolveAuthorizationStatus(calendar: Calendar) async -> CycleAuthStatus { status }

    func requestAuthorization() async throws {
        // Previews/tests: no-op
    }

    func fetchMenstrualFlowDays(calendar: Calendar) async throws -> Set<Date> {
        periodDays
    }

    /// A 28-day cycle with period starting 20 days ago (currently luteal, day 21).
    static func lutealSample(calendar: Calendar = .current) -> MockCycleDataProvider {
        let today = calendar.startOfDay(for: .now)
        guard let periodStart = calendar.date(byAdding: .day, value: -20, to: today) else {
            return MockCycleDataProvider()
        }
        let days = (0..<5).compactMap { calendar.date(byAdding: .day, value: $0, to: periodStart) }
        return MockCycleDataProvider(periodDays: Set(days))
    }
}
