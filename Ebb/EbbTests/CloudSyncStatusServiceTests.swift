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
    @Test func cloudKitWithAccountShowsSyncingLabel() {
        let label = CloudSyncStatusService.makeStatusLabel(
            storageMode: .cloudKit,
            accountStatus: .available
        )
        #expect(label == "Syncing · iCloud")
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
}

@Suite("Cloud sync restore monitoring")
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

    @Test func importCompletionWithNoEntriesMarksNoBackupFound() {
        let service = CloudSyncStatusService(storageMode: .cloudKit)
        service.setAccountStatusForTesting(.available)
        service.monitorRestore(entryCount: 0)
        #expect(service.restorePhase == .restoring)

        NotificationCenter.default.post(name: .ebbCloudKitImportFinished, object: nil)
        service.monitorRestore(entryCount: 0)

        #expect(service.restorePhase == .noBackupFound)
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
