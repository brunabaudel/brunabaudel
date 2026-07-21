import CloudKit
import Foundation

/// Result of querying CloudKit for exported symptom entries.
enum CloudKitBackupVerificationResult: Equatable, Sendable {
    case confirmed
    case notFound
    case transientFailure
}

/// Confirms symptom entries exist in the user's private CloudKit database.
enum CloudKitBackupVerifier {
    static let recordType = "CD_SymptomEntry"
    static let zoneID = CKRecordZone.ID(
        zoneName: "com.apple.coredata.cloudkit.zone",
        ownerName: CKCurrentUserDefaultName
    )

    static func verifyBackup(
        containerIdentifier: String = CloudSyncStatusService.containerIdentifier
    ) async -> CloudKitBackupVerificationResult {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))

        do {
            let (matchResults, _) = try await database.records(
                matching: query,
                inZoneWith: zoneID,
                resultsLimit: 1
            )
            let hasRecord = matchResults.contains { _, result in
                if case .success = result { return true }
                return false
            }
            return hasRecord ? .confirmed : .notFound
        } catch let error as CKError {
            if isTransient(error) {
                NSLog("CloudKit backup verification transient: \(error.localizedDescription)")
                return .transientFailure
            }
            // Schema or indexes may not exist yet on first launch — keep checking.
            NSLog("CloudKit backup verification: \(error.localizedDescription)")
            return .notFound
        } catch {
            NSLog("CloudKit backup verification failed: \(error.localizedDescription)")
            return .transientFailure
        }
    }

    static func hasBackupRecords(
        containerIdentifier: String = CloudSyncStatusService.containerIdentifier
    ) async -> Bool {
        await verifyBackup(containerIdentifier: containerIdentifier) == .confirmed
    }

    private static func isTransient(_ error: CKError) -> Bool {
        switch error.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable,
             .requestRateLimited, .zoneBusy, .serverResponseLost,
             .zoneNotFound, .userCancelled, .operationCancelled:
            true
        default:
            false
        }
    }
}
