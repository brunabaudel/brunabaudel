import CloudKit
import Foundation

/// Result of checking whether symptom entries exist in the user's private CloudKit zone.
enum CloudKitBackupVerificationResult: Equatable, Sendable {
    case confirmed
    case notFound
    case transientFailure
}

/// Confirms symptom entries exist in the Core Data CloudKit mirror zone.
enum CloudKitBackupVerifier {
    static let recordType = "CD_SymptomEntry"
    static let zoneID = CKRecordZone.ID(
        zoneName: "com.apple.coredata.cloudkit.zone",
        ownerName: CKCurrentUserDefaultName
    )

    static func verifyBackup(
        containerIdentifier: String = CloudSyncStatusService.containerIdentifier
    ) async -> CloudKitBackupVerificationResult {
        guard AppRuntime.shouldUseCloudKitSync else {
            return .notFound
        }

        return await Task.detached(priority: .utility) {
            await verifyBackupOnBackgroundThread(containerIdentifier: containerIdentifier)
        }.value
    }

    private static func verifyBackupOnBackgroundThread(
        containerIdentifier: String
    ) async -> CloudKitBackupVerificationResult {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase

        let zoneResult = await verifyViaZoneChanges(database: database)
        switch zoneResult {
        case .confirmed, .transientFailure:
            return zoneResult
        case .notFound:
            return await verifyViaQuery(database: database)
        }
    }

    private static func verifyViaZoneChanges(database: CKDatabase) async -> CloudKitBackupVerificationResult {
        var changeToken: CKServerChangeToken?
        var moreComing = true

        do {
            while moreComing {
                let batch = try await database.recordZoneChanges(
                    inZoneWith: zoneID,
                    since: changeToken,
                    resultsLimit: 100
                )

                for (_, result) in batch.modificationResultsByID {
                    guard case .success(let modification) = result else { continue }
                    if isBackupRecord(modification.record) {
                        return .confirmed
                    }
                }

                changeToken = batch.changeToken
                moreComing = batch.moreComing
            }
            return .notFound
        } catch let error as CKError {
            if isTransient(error) {
                NSLog("CloudKit backup zone verification transient: \(error.localizedDescription)")
                return .transientFailure
            }
            NSLog("CloudKit backup zone verification: \(error.localizedDescription)")
            return .transientFailure
        } catch {
            NSLog("CloudKit backup zone verification failed: \(error.localizedDescription)")
            return .transientFailure
        }
    }

    /// Fallback when zone-change fetch is empty but `recordName` is queryable in the dashboard.
    private static func verifyViaQuery(database: CKDatabase) async -> CloudKitBackupVerificationResult {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        do {
            let (matchResults, _) = try await database.records(
                matching: query,
                inZoneWith: zoneID,
                desiredKeys: [],
                resultsLimit: 1
            )
            if matchResults.contains(where: { _, result in
                if case .success = result { return true }
                return false
            }) {
                return .confirmed
            }
            return .notFound
        } catch let error as CKError {
            if isTransient(error) {
                NSLog("CloudKit backup query verification transient: \(error.localizedDescription)")
                return .transientFailure
            }
            NSLog("CloudKit backup query verification: \(error.localizedDescription)")
            return .notFound
        } catch {
            NSLog("CloudKit backup query verification failed: \(error.localizedDescription)")
            return .notFound
        }
    }

    private static func isBackupRecord(_ record: CKRecord) -> Bool {
        if record.recordType == recordType {
            return true
        }
        return record.recordType.hasPrefix("CD_")
    }

    private static func isTransient(_ error: CKError) -> Bool {
        switch error.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable,
             .requestRateLimited, .zoneBusy, .serverResponseLost, .zoneNotFound,
             .partialFailure:
            true
        default:
            false
        }
    }
}
