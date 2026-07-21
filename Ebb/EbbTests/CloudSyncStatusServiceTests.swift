import CloudKit
import Foundation
import Testing
@testable import Ebb

@Suite("Sync preferences")
struct SyncPreferencesTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "SyncPreferencesTests.\(UUID().uuidString)")!
    }

    @Test func iCloudSyncEnabledDefaultsToTrue() {
        let defaults = makeDefaults()
        let preferences = SyncPreferences(defaults: defaults)
        #expect(preferences.iCloudSyncEnabled == true)
    }

    @Test func iCloudSyncEnabledPersists() {
        let defaults = makeDefaults()
        let preferences = SyncPreferences(defaults: defaults)
        preferences.iCloudSyncEnabled = false
        #expect(defaults.bool(forKey: SyncPreferences.iCloudSyncEnabledKey) == false)
    }
}

@Suite("Cloud sync status labels")
struct CloudSyncStatusLabelTests {
    @Test func cloudKitWithAccountShowsOnLabel() {
        let label = CloudSyncStatusService.makeStatusLabel(
            storageMode: .cloudKit,
            accountStatus: .available
        )
        #expect(label == "On · iCloud")
    }

    @Test func localByChoiceShowsOnDeviceOnly() {
        let label = CloudSyncStatusService.makeStatusLabel(
            storageMode: .localByChoice,
            accountStatus: .available
        )
        #expect(label == "On device only")
    }

    @Test func localFallbackShowsUnavailableHintWhenSignedIn() {
        let label = CloudSyncStatusService.makeStatusLabel(
            storageMode: .localFallback,
            accountStatus: .available
        )
        #expect(label == "On device only — iCloud unavailable")
    }

    @Test func restoringShowsRestoreLabel() {
        let label = CloudSyncStatusService.makeStatusLabel(
            storageMode: .cloudKit,
            accountStatus: .available,
            restorePhase: .restoring
        )
        #expect(label == "Restoring from iCloud…")
    }

    @Test func noBackupFoundShowsExplicitLabel() {
        let label = CloudSyncStatusService.makeStatusLabel(
            storageMode: .cloudKit,
            accountStatus: .available,
            restorePhase: .noBackupFound
        )
        #expect(label == "No iCloud backup found")
    }

    @Test func noBackupFoundWithLocalEntriesShowsBackingUp() {
        let label = CloudSyncStatusService.makeStatusLabel(
            storageMode: .cloudKit,
            accountStatus: .available,
            restorePhase: .noBackupFound,
            localEntryCount: 1
        )
        #expect(label == "Backing up to iCloud…")
    }

    @Test func confirmedBackupShowsBackedUpLabel() {
        let label = CloudSyncStatusService.makeStatusLabel(
            storageMode: .cloudKit,
            accountStatus: .available,
            hasConfirmedBackup: true
        )
        #expect(label == "Backed up · iCloud")
    }

    @Test func unverifiedEntriesShowBackingUpLabel() {
        let label = CloudSyncStatusService.makeStatusLabel(
            storageMode: .cloudKit,
            accountStatus: .available,
            localEntryCount: 2
        )
        #expect(label == "Backing up to iCloud…")
    }
}

@Suite("Cloud sync restore monitoring", .serialized)
@MainActor
struct CloudRestoreMonitoringTests {
    @Test func restoreCompletesWhenEntriesAppear() {
        let service = CloudSyncStatusService(storageMode: .cloudKit)
        service.setAccountStatusForTesting(.available)

        service.monitorRestore(entryCount: 0)
        #expect(service.restorePhase == .restoring)

        service.monitorRestore(entryCount: 2)
        #expect(service.restorePhase == .restored)
    }

    @Test func localStorageSkipsRestoreMonitoring() {
        let service = CloudSyncStatusService(storageMode: .localByChoice)
        service.setAccountStatusForTesting(.available)
        service.monitorRestore(entryCount: 0)
        #expect(service.restorePhase == .idle)
    }

    @Test func restoreStartsAfterAccountBecomesAvailable() {
        let service = CloudSyncStatusService(storageMode: .cloudKit)
        service.monitorRestore(entryCount: 0)
        #expect(service.restorePhase == .idle)

        service.setAccountStatusForTesting(.available)
        service.monitorRestore(entryCount: 0)
        #expect(service.restorePhase == .restoring)
    }

    @Test func importCompletionWithNoEntriesMarksNoBackupFound() {
        let service = CloudSyncStatusService(storageMode: .cloudKit)
        service.setAccountStatusForTesting(.available)
        service.monitorRestore(entryCount: 0)
        #expect(service.restorePhase == .restoring)

        NotificationCenter.default.post(name: .ebbCloudKitImportFinished, object: nil)
        service.monitorRestore(entryCount: 0)

        #expect(service.restorePhase == .noBackupFound)
    }

    @Test func importFinishedGenerationIncrements() {
        let service = CloudSyncStatusService(storageMode: .cloudKit)
        service.setAccountStatusForTesting(.available)
        let before = service.importFinishedGeneration

        NotificationCenter.default.post(name: .ebbCloudKitImportFinished, object: nil)

        #expect(service.importFinishedGeneration == before + 1)
    }

    @Test func exportEventConfirmsBackupAfterPendingSave() {
        let service = CloudSyncStatusService(storageMode: .cloudKit)
        service.setAccountStatusForTesting(.available)
        NotificationCenter.default.post(name: .ebbLocalEntrySaved, object: nil)
        #expect(service.hasConfirmedBackup == false)

        NotificationCenter.default.post(name: .ebbCloudKitExportFinished, object: nil)

        #expect(service.hasConfirmedBackup == true)
        #expect(service.statusLabel == "Backed up · iCloud")
        #expect(service.backupProgress == 1)
    }

    @Test func exportEventDoesNotConfirmWithoutPendingSave() {
        let service = CloudSyncStatusService(storageMode: .cloudKit)
        service.setAccountStatusForTesting(.available)
        service.noteEntryCount(1)

        NotificationCenter.default.post(name: .ebbCloudKitExportFinished, object: nil)

        #expect(service.hasConfirmedBackup == false)
    }

    @Test func zoneVerificationConfirmsExistingBackup() async {
        let service = CloudSyncStatusService(storageMode: .cloudKit)
        service.setAccountStatusForTesting(.available)
        service.setVerifyBackupHandlerForTesting { .confirmed }
        service.noteEntryCount(1)

        for _ in 0..<100 where !service.hasConfirmedBackup {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        #expect(service.hasConfirmedBackup == true)
        #expect(service.statusLabel == "Backed up · iCloud")
    }

    @Test func verificationTimeoutStallsWhenZoneHasNoRecords() async {
        let service = CloudSyncStatusService(storageMode: .cloudKit)
        service.setAccountStatusForTesting(.available)
        service.setVerifyBackupHandlerForTesting { .notFound }
        NotificationCenter.default.post(name: .ebbLocalEntrySaved, object: nil)

        for _ in 0..<200 where !service.hasConfirmedBackup && service.backupPhase != .stalled {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        #expect(service.hasConfirmedBackup == false)
        #expect(service.backupPhase == .stalled)
    }

    @Test func localSaveNotificationConfirmsAfterExport() {
        let service = CloudSyncStatusService(storageMode: .cloudKit)
        service.setAccountStatusForTesting(.available)
        NotificationCenter.default.post(name: .ebbLocalEntrySaved, object: nil)
        #expect(service.statusLabel == "Backing up to iCloud…")
        #expect(service.backupPhase == .savedLocally)
        #expect(service.backupProgress == 0.2)

        NotificationCenter.default.post(name: .ebbCloudKitExportStarted, object: nil)
        #expect(service.backupPhase == .uploading)
        #expect(service.isExportInProgress == true)

        NotificationCenter.default.post(name: .ebbCloudKitExportFinished, object: nil)
        #expect(service.hasConfirmedBackup == true)
        #expect(service.statusLabel == "Backed up · iCloud")
        #expect(service.backupProgress == 1)
    }

    @Test func exportEventConfirmsBackupWithLocalEntriesAfterSave() {
        let service = CloudSyncStatusService(storageMode: .cloudKit)
        service.setAccountStatusForTesting(.available)
        service.setRestorePhaseForTesting(.noBackupFound)
        NotificationCenter.default.post(name: .ebbLocalEntrySaved, object: nil)
        #expect(service.statusLabel == "Backing up to iCloud…")

        NotificationCenter.default.post(name: .ebbCloudKitExportFinished, object: nil)

        #expect(service.hasConfirmedBackup == true)
        #expect(service.statusLabel == "Backed up · iCloud")
    }

    @Test func addingEntriesClearsStaleNoBackupLabel() {
        let service = CloudSyncStatusService(storageMode: .cloudKit)
        service.setAccountStatusForTesting(.available)
        service.setRestorePhaseForTesting(.noBackupFound)
        service.noteEntryCount(1)
        #expect(service.statusLabel == "Backing up to iCloud…")
    }

    @Test func localEntriesDoNotConfirmBackupWithoutExportOrZoneMatch() async {
        let service = CloudSyncStatusService(storageMode: .cloudKit)
        service.setAccountStatusForTesting(.available)
        service.setVerifyBackupHandlerForTesting { .notFound }
        service.noteEntryCount(2)

        for _ in 0..<80 where service.isVerifyingBackup {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        #expect(service.hasConfirmedBackup == false)
        #expect(service.statusLabel == "Backing up to iCloud…")
    }

    @Test func retryBackupAttemptRestartsProgress() {
        let service = CloudSyncStatusService(storageMode: .cloudKit)
        service.setAccountStatusForTesting(.available)
        service.setBackupPhaseForTesting(.stalled)
        service.setBackupProgressForTesting(0.9)
        service.noteEntryCount(1)

        service.retryBackupAttempt()

        #expect(service.backupPhase == .savedLocally)
        #expect(service.backupProgress == 0.2)
        #expect(service.lastBackupError == nil)
    }

    @Test func exportFailureMarksBackupStalled() {
        let service = CloudSyncStatusService(storageMode: .cloudKit)
        service.setAccountStatusForTesting(.available)
        NotificationCenter.default.post(name: .ebbLocalEntrySaved, object: nil)

        NotificationCenter.default.post(
            name: .ebbCloudKitExportFailed,
            object: nil,
            userInfo: ["error": "iCloud isn't reachable right now. Connect to Wi‑Fi and try again."]
        )

        #expect(service.backupPhase == .stalled)
        #expect(service.lastBackupError == "iCloud isn't reachable right now. Connect to Wi‑Fi and try again.")
        #expect(service.isVerifyingBackup == false)
    }

    @Test func exportFailureBlocksLaterExportSuccessFromConfirming() {
        let service = CloudSyncStatusService(storageMode: .cloudKit)
        service.setAccountStatusForTesting(.available)
        service.noteEntryCount(1)

        NotificationCenter.default.post(
            name: .ebbCloudKitExportFailed,
            object: nil,
            userInfo: [
                "error": "iCloud couldn't finish uploading all of your logs. Stay on Wi‑Fi, keep Ebb open, and tap Retry backup."
            ]
        )

        #expect(service.backupPhase == .stalled)
        #expect(service.hasConfirmedBackup == false)

        NotificationCenter.default.post(name: .ebbCloudKitExportFinished, object: nil)

        #expect(service.backupPhase == .stalled)
        #expect(service.hasConfirmedBackup == false)
        #expect(service.isVerifyingBackup == false)
    }
}

@Suite("CloudSyncStatusService")
@MainActor
struct CloudSyncStatusServiceTests {
    @Test func usesExpectedContainerIdentifier() {
        #expect(CloudSyncStatusService.containerIdentifier == "iCloud.com.bcbs.ebb")
    }

    @Test func cloudKitModeIsSyncActiveOnlyWithAvailableAccount() {
        let service = CloudSyncStatusService(storageMode: .cloudKit)
        service.setAccountStatusForTesting(.available)
        #expect(service.isCloudKitSyncActive == true)
    }
}
