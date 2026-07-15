import Foundation
import HealthKit

final class HealthKitCycleDataProvider: CycleDataProvider, @unchecked Sendable {
    private let store = HKHealthStore()
    private let menstrualFlow = HKObjectType.categoryType(forIdentifier: .menstrualFlow)!

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func authorizationStatus() -> CycleAuthStatus {
        guard isAvailable else { return .unavailable }
        switch store.authorizationStatus(for: menstrualFlow) {
        case .notDetermined:
            return .notDetermined
        case .sharingDenied:
            return .denied
        case .sharingAuthorized:
            return .authorized
        @unknown default:
            return .denied
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

    private static func isLoggedFlow(_ sample: HKCategorySample) -> Bool {
        switch HKCategoryValueMenstrualFlow(rawValue: sample.value) {
        case .light, .medium, .heavy:
            return true
        default:
            return false
        }
    }
}
