import Foundation
import HealthKit

final class HealthKitCycleDataProvider: CycleDataProvider, @unchecked Sendable {
    private let store = HKHealthStore()
    private let menstrualFlow = HKObjectType.categoryType(forIdentifier: .menstrualFlow)!

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func resolveAuthorizationStatus(calendar: Calendar) async -> CycleAuthStatus {
        guard isAvailable else { return .unavailable }

        let requestStatus = await requestStatus()
        switch requestStatus {
        case .shouldRequest:
            return .notDetermined
        case .unnecessary:
            // Read authorization is intentionally opaque — sharingDenied does not mean
            // the user refused. After the sheet, assume connected and probe with a query.
            return await probeReadAccess(calendar: calendar)
        case .unknown:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: [], read: [menstrualFlow])
    }

    func fetchMenstrualFlowDays(calendar: Calendar) async throws -> Set<Date> {
        guard isAvailable else { return [] }

        let end = Date.now
        guard let start = calendar.date(byAdding: .day, value: -400, to: end) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: menstrualFlow,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let days = Set(
                    (samples as? [HKCategorySample] ?? [])
                        .filter(Self.isLoggedFlow)
                        .map { calendar.startOfDay(for: $0.startDate) }
                )
                continuation.resume(returning: days)
            }
            store.execute(query)
        }
    }

    // MARK: - Private

    private func requestStatus() async -> HKAuthorizationRequestStatus {
        await withCheckedContinuation { continuation in
            store.getRequestStatusForAuthorization(toShare: [], read: [menstrualFlow]) { status, _ in
                continuation.resume(returning: status)
            }
        }
    }

    /// Confirms the app can issue read queries. An empty result still counts as access.
    private func probeReadAccess(calendar: Calendar) async -> CycleAuthStatus {
        do {
            _ = try await fetchMenstrualFlowDays(calendar: calendar)
            return .authorized
        } catch let error as HKError where error.code == .errorAuthorizationDenied {
            return .denied
        } catch {
            // Transient HealthKit errors should not strand the user on "access denied".
            return .authorized
        }
    }

    private static func isLoggedFlow(_ sample: HKCategorySample) -> Bool {
        switch HKCategoryValueMenstrualFlow(rawValue: sample.value) {
        case .light, .medium, .heavy:
            return true
        default:
            return false
        }
    }
}
