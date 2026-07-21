import CloudKit
import Foundation

/// Result of checking whether symptom entries exist in the user's private CloudKit zone.
enum CloudKitBackupVerificationResult: Equatable, Sendable {
    case confirmed
    case notFound
    case transientFailure
}

/// Confirms symptom entries exist in the Core Data CloudKit mirror zone.
///
/// SwiftData record types are not queryable with `NSPredicate(value: true)` unless
/// `recordName` is indexed in the CloudKit dashboard. Zone-change fetch works without
/// query indexes and is the reliable way to detect exported `CD_SymptomEntry` records.
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
        var changeToken: CKServerChangeToken?
        var moreComing = true

        do {
            while moreComing {
                let batch = try await database.recordZoneChanges(
                    inZoneWith: zoneID,
                    since: changeToken,
                    resultsLimit: 50
                )

                for (_, result) in batch.modificationResultsByID {
                    guard case .success(let modification) = result else { continue }
                    if modification.record.recordType == recordType {
                        return .confirmed
                    }
                }

                changeToken = batch.changeToken
                moreComing = batch.moreComing
            }
            return .notFound
        } catch let error as CKError {
            if isTransient(error) {
                NSLog("CloudKit backup verification transient: \(error.localizedDescription)")
                return .transientFailure
            }
            NSLog("CloudKit backup verification: \(error.localizedDescription)")
            return .transientFailure
        } catch {
            NSLog("CloudKit backup verification failed: \(error.localizedDescription)")
            return .transientFailure
        }
    }

    private static func isTransient(_ error: CKError) -> Bool {
        switch error.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable,
             .requestRateLimited, .zoneBusy, .serverResponseLost, .zoneNotFound:
            true
        default:
            false
        }
    }
}
