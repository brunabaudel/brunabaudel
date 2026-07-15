import Foundation

enum CycleAuthStatus: Equatable, Sendable {
    case unavailable
    case notDetermined
    case authorized
    case denied
}

/// HealthKit reads + cycle data — mockable for previews and unit tests.
protocol CycleDataProvider: Sendable {
    var isAvailable: Bool { get }
    func authorizationStatus() -> CycleAuthStatus
    func requestAuthorization() async throws
    func fetchMenstrualFlowDays(calendar: Calendar) async throws -> Set<Date>
}
