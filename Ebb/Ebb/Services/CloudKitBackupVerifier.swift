import CloudKit
import Foundation

/// Confirms symptom entries exist in the user's private CloudKit database.
enum CloudKitBackupVerifier {
    static let recordType = "CD_SymptomEntry"
    static let zoneID = CKRecordZone.ID(
        zoneName: "com.apple.coredata.cloudkit.zone",
        ownerName: CKCurrentUserDefaultName
    )

    static func hasBackupRecords(
        containerIdentifier: String = CloudSyncStatusService.containerIdentifier
    ) async -> Bool {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))

        do {
            let (matchResults, _) = try await database.records(
                matching: query,
                inZoneWith: zoneID,
                resultsLimit: 1
            )
            return matchResults.contains { _, result in
                if case .success = result { return true }
                return false
            }
        } catch let error as CKError {
            // Schema or indexes may not exist yet on first launch — treat as no backup.
            NSLog("CloudKit backup verification: \(error.localizedDescription)")
            return false
        } catch {
            NSLog("CloudKit backup verification failed: \(error.localizedDescription)")
            return false
        }
    }
}
