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
    /// True after CloudKit export succeeds or records are verified in iCloud.
    private(set) var hasConfirmedBackup = false
    private(set) var isVerifyingBackup = false
    private(set) var lastBackupError: String?

    /// True when entries are actively syncing through CloudKit on this launch.
    var isCloudKitSyncActive: Bool {
        storageMode == .cloudKit && accountStatus == .available
    }

    private let container: CKContainer?
    private var restoreTimeoutTask: Task<Void, Never>?
    private var verificationTask: Task<Void, Never>?
    private var importObserver: NSObjectProtocol?
    private var exportObserver: NSObjectProtocol?
    private var exportFailedObserver: NSObjectProtocol?
    private var localSaveObserver: NSObjectProtocol?
    private var cloudImportCompleted = false
    private var localEntryCount = 0
    private var awaitingExportAfterSave = false
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

        exportFailedObserver = NotificationCenter.default.addObserver(
            forName: .ebbCloudKitExportFailed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.handleExportFailed(
                    notification.userInfo?["error"] as? String
                )
            }
        }

        localSaveObserver = NotificationCenter.default.addObserver(
            forName: .ebbLocalEntrySaved,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.handleLocalEntrySaved()
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

    func setRestorePhaseForTesting(_ phase: CloudRestorePhase) {
        restorePhase = phase
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
        clearStaleNoBackupStateIfNeeded()
        guard isCloudKitSyncActive, count > 0, !hasConfirmedBackup else {
            updateStatusLabel()
            return
        }
        updateStatusLabel()
        scheduleBackupVerification()
    }

    /// Call from a view that owns the entry query so restore UI reflects real data.
    func monitorRestore(entryCount: Int) {
        localEntryCount = entryCount
        guard isCloudKitSyncActive else { return }

        if entryCount > 0 {
            clearStaleNoBackupStateIfNeeded()
            if restorePhase == .restoring {
                confirmBackupFromCloudKit()
                finishRestoreMonitoring(as: .restored)
            } else if !hasConfirmedBackup {
                scheduleBackupVerification()
            }
            updateStatusLabel()
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

    private func clearStaleNoBackupStateIfNeeded() {
        guard localEntryCount > 0, restorePhase == .noBackupFound else { return }
        restorePhase = .idle
    }

    private func handleImportFinished() {
        cloudImportCompleted = true
        restoreTimeoutTask?.cancel()
        restoreTimeoutTask = nil
        importFinishedGeneration += 1
    }

    private func handleExportFinished() {
        guard !hasConfirmedBackup else { return }
        lastBackupError = nil
        if awaitingExportAfterSave || localEntryCount > 0 {
            confirmBackupFromCloudKit()
        }
    }

    private func handleExportFailed(_ message: String?) {
        guard awaitingExportAfterSave || localEntryCount > 0 else { return }
        lastBackupError = message ?? "iCloud upload failed. Keep Ebb open on Wi‑Fi and try again."
        isVerifyingBackup = false
        updateStatusLabel()
    }

    private func handleLocalEntrySaved() {
        guard isCloudKitSyncActive, !hasConfirmedBackup else { return }
        awaitingExportAfterSave = true
        lastBackupError = nil
        if localEntryCount == 0 {
            localEntryCount = 1
        }
        clearStaleNoBackupStateIfNeeded()
        updateStatusLabel()
        scheduleBackupVerification()
    }

    private func confirmBackupFromCloudKit() {
        verificationTask?.cancel()
        verificationTask = nil
        isVerifyingBackup = false
        awaitingExportAfterSave = false
        hasConfirmedBackup = true
        lastBackupError = nil
        clearStaleNoBackupStateIfNeeded()
        updateStatusLabel()
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
                    confirmBackupFromCloudKit()
                    return
                }
            }

            isVerifyingBackup = false
            if awaitingExportAfterSave, localEntryCount > 0 {
                lastBackupError = "Upload is taking longer than expected. Keep Ebb open on Wi‑Fi."
            }
            updateStatusLabel()
        }
    }

    private static var verificationRetryDelaysSeconds: [Double] {
        AppRuntime.isRunningTests ? [0.01, 0.01, 0.01, 0.01, 0.01] : [3, 8, 15, 30, 60]
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
            switch accountStatus {
            case .available:
                if hasConfirmedBackup {
                    return "Backed up · iCloud"
                }
                if isVerifyingBackup || localEntryCount > 0 {
                    return "Backing up to iCloud…"
                }
                if restorePhase == .noBackupFound {
                    return "No iCloud backup found"
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
