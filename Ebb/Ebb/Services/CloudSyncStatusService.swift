import CloudKit
import Foundation
import Observation

/// Whether iCloud restore is in progress after install or first launch.
enum CloudRestorePhase: Equatable, Sendable {
    case idle
    case restoring
    case restored
    case noBackupFound
}

/// Surfaces iCloud account status, actual storage mode, and restore progress (Phase 8).
@Observable
@MainActor
final class CloudSyncStatusService {
    nonisolated static let containerIdentifier = "iCloud.com.bcbs.ebb"
    private static let restoreTimeoutSeconds: UInt64 = 180

    private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    private(set) var statusLabel: String
    private(set) var isAvailable = false
    private(set) var storageMode: AppStorageMode = .localFallback
    private(set) var restorePhase: CloudRestorePhase = .idle
    /// Bumped when CloudKit import finishes so views can re-check restore state.
    private(set) var importFinishedGeneration = 0
    /// True only after CloudKit confirms records exist for this Apple ID.
    private(set) var hasConfirmedBackup = false
    private(set) var isVerifyingBackup = false

    /// True when entries are actively syncing through CloudKit on this launch.
    var isCloudKitSyncActive: Bool {
        storageMode == .cloudKit && accountStatus == .available
    }

    private let container: CKContainer?
    private var restoreTimeoutTask: Task<Void, Never>?
    private var verificationTask: Task<Void, Never>?
    private var importObserver: NSObjectProtocol?
    private var exportObserver: NSObjectProtocol?
    private var cloudImportCompleted = false
    private var localEntryCount = 0
    private var verifyBackupHandler: @Sendable () async -> Bool

    init(
        storageMode: AppStorageMode = .localFallback,
        containerIdentifier: String = CloudSyncStatusService.containerIdentifier
    ) {
        self.storageMode = storageMode
        verifyBackupHandler = {
            await CloudKitBackupVerifier.hasBackupRecords(containerIdentifier: containerIdentifier)
        }
        if AppRuntime.shouldUseCloudKitSync {
            container = CKContainer(identifier: containerIdentifier)
            statusLabel = Self.makeStatusLabel(
                storageMode: storageMode,
                accountStatus: .couldNotDetermine
            )
        } else {
            container = nil
            statusLabel = Self.makeStatusLabel(
                storageMode: storageMode,
                accountStatus: .couldNotDetermine
            )
        }

        importObserver = NotificationCenter.default.addObserver(
            forName: .ebbCloudKitImportFinished,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.handleImportFinished()
            }
        }

        exportObserver = NotificationCenter.default.addObserver(
            forName: .ebbCloudKitExportFinished,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.handleExportFinished()
            }
        }
    }

    func configure(storageMode: AppStorageMode) {
        self.storageMode = storageMode
        updateStatusLabel()
    }

    /// Test seam — production code uses `refresh()` against CloudKit.
    func setAccountStatusForTesting(_ status: CKAccountStatus) {
        accountStatus = status
        isAvailable = status == .available
        updateStatusLabel()
    }

    func setVerifyBackupHandlerForTesting(_ handler: @escaping @Sendable () async -> Bool) {
        verifyBackupHandler = handler
    }

    func refresh() async {
        guard let container else {
            accountStatus = .couldNotDetermine
            isAvailable = false
            updateStatusLabel()
            return
        }

        do {
            accountStatus = try await container.accountStatus()
            isAvailable = accountStatus == .available
        } catch {
            accountStatus = .couldNotDetermine
            isAvailable = false
        }
        updateStatusLabel()
    }

    /// Track local entries and verify backup when data exists but is not confirmed yet.
    func noteEntryCount(_ count: Int) {
        localEntryCount = count
        guard isCloudKitSyncActive, count > 0, !hasConfirmedBackup else { return }
        updateStatusLabel()
        scheduleBackupVerification()
    }

    /// Call from a view that owns the entry query so restore UI reflects real data.
    func monitorRestore(entryCount: Int) {
        localEntryCount = entryCount
        guard isCloudKitSyncActive else { return }

        if entryCount > 0 {
            if restorePhase == .restoring {
                hasConfirmedBackup = true
                finishRestoreMonitoring(as: .restored)
            }
            if !hasConfirmedBackup {
                scheduleBackupVerification()
            }
            return
        }

        if cloudImportCompleted {
            finishRestoreMonitoring(as: .noBackupFound)
            return
        }

        switch restorePhase {
        case .restored, .noBackupFound:
            return
        case .idle:
            restorePhase = .restoring
            updateStatusLabel()
            startRestoreTimeout()
        case .restoring:
            break
        }
    }

    // MARK: - Private

    private func handleImportFinished() {
        cloudImportCompleted = true
        restoreTimeoutTask?.cancel()
        restoreTimeoutTask = nil
        importFinishedGeneration += 1
    }

    private func handleExportFinished() {
        guard localEntryCount > 0, !hasConfirmedBackup else { return }
        scheduleBackupVerification()
    }

    private func scheduleBackupVerification() {
        verificationTask?.cancel()
        verificationTask = Task {
            isVerifyingBackup = true
            updateStatusLabel()

            let retryDelaysSeconds = Self.verificationRetryDelaysSeconds
            for delay in retryDelaysSeconds {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled, localEntryCount > 0, !hasConfirmedBackup else {
                    isVerifyingBackup = false
                    updateStatusLabel()
                    return
                }

                if await verifyBackupHandler() {
                    hasConfirmedBackup = true
                    isVerifyingBackup = false
                    updateStatusLabel()
                    return
                }
            }

            isVerifyingBackup = false
            updateStatusLabel()
        }
    }

    private static var verificationRetryDelaysSeconds: [Double] {
        AppRuntime.isRunningTests ? [0.01] : [3, 8, 15, 30, 60]
    }

    private func startRestoreTimeout() {
        restoreTimeoutTask?.cancel()
        restoreTimeoutTask = Task {
            try? await Task.sleep(nanoseconds: Self.restoreTimeoutSeconds * 1_000_000_000)
            guard !Task.isCancelled, restorePhase == .restoring else { return }
            cloudImportCompleted = true
            restorePhase = .noBackupFound
            updateStatusLabel()
        }
    }

    private func finishRestoreMonitoring(as phase: CloudRestorePhase) {
        restoreTimeoutTask?.cancel()
        restoreTimeoutTask = nil
        restorePhase = phase
        updateStatusLabel()
    }

    private func updateStatusLabel() {
        statusLabel = Self.makeStatusLabel(
            storageMode: storageMode,
            accountStatus: accountStatus,
            restorePhase: restorePhase,
            hasConfirmedBackup: hasConfirmedBackup,
            isVerifyingBackup: isVerifyingBackup,
            localEntryCount: localEntryCount
        )
    }

    nonisolated static func makeStatusLabel(
        storageMode: AppStorageMode,
        accountStatus: CKAccountStatus,
        restorePhase: CloudRestorePhase = .idle,
        hasConfirmedBackup: Bool = false,
        isVerifyingBackup: Bool = false,
        localEntryCount: Int = 0
    ) -> String {
        switch storageMode {
        case .inMemoryTesting:
            return "On device"
        case .inMemoryFallback:
            return "Temporary storage"
        case .localByChoice:
            return "On device only"
        case .localFallback:
            switch accountStatus {
            case .available, .temporarilyUnavailable:
                return "On device only — iCloud unavailable"
            default:
                return "On device only"
            }
        case .cloudKit:
            if restorePhase == .restoring {
                return "Restoring from iCloud…"
            }
            if restorePhase == .noBackupFound {
                return "No iCloud backup found"
            }
            switch accountStatus {
            case .available:
                if hasConfirmedBackup {
                    return "Backed up · iCloud"
                }
                if isVerifyingBackup || localEntryCount > 0 {
                    return "Backing up to iCloud…"
                }
                return "On · iCloud"
            case .noAccount:
                return "Sign in to iCloud"
            case .restricted:
                return "Restricted"
            case .temporarilyUnavailable:
                return "Temporarily unavailable"
            case .couldNotDetermine:
                return "Checking…"
            @unknown default:
                return "Unavailable"
            }
        }
    }
}
