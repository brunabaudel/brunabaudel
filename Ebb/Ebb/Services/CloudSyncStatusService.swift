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

/// Stages shown in backup progress UI. CloudKit does not expose byte-level upload progress.
enum CloudBackupPhase: Equatable, Sendable {
    case idle
    case savedLocally
    case uploading
    case confirming
    case backedUp
    case stalled
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
    private(set) var backupPhase: CloudBackupPhase = .idle
    /// Estimated backup progress from 0 (idle) to 1 (confirmed in iCloud).
    private(set) var backupProgress: Double = 0
    private(set) var isExportInProgress = false
    private(set) var verificationStep = 0
    private(set) var verificationStepCount = 5
    private(set) var iCloudAccountSummary = "Checking…"

    /// Number of local entries tracked for backup status.
    var trackedEntryCount: Int { localEntryCount }

    /// True while backup UI should show an active progress indicator.
    var isBackupInProgress: Bool {
        switch backupPhase {
        case .savedLocally, .uploading, .confirming:
            true
        case .idle, .backedUp, .stalled:
            false
        }
    }

    var backupPhaseLabel: String {
        switch backupPhase {
        case .idle:
            return "Ready"
        case .savedLocally:
            return "Saved on this iPhone"
        case .uploading:
            return isExportInProgress ? "Uploading to iCloud…" : "Waiting for iCloud upload…"
        case .confirming:
            return "Confirming in iCloud…"
        case .backedUp:
            return "Backed up · iCloud"
        case .stalled:
            return "Upload paused"
        }
    }

    /// True when entries are actively syncing through CloudKit on this launch.
    var isCloudKitSyncActive: Bool {
        storageMode == .cloudKit && accountStatus == .available
    }

    private let container: CKContainer?
    private var restoreTimeoutTask: Task<Void, Never>?
    private var verificationTask: Task<Void, Never>?
    private var importObserver: NSObjectProtocol?
    private var exportObserver: NSObjectProtocol?
    private var exportStartedObserver: NSObjectProtocol?
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

        exportStartedObserver = NotificationCenter.default.addObserver(
            forName: .ebbCloudKitExportStarted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.handleExportStarted()
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

    func setBackupPhaseForTesting(_ phase: CloudBackupPhase) {
        backupPhase = phase
    }

    func setBackupProgressForTesting(_ progress: Double) {
        backupProgress = progress
    }

    /// Re-check iCloud account state and refresh the account summary shown in Settings.
    func refresh() async {
        guard let container else {
            accountStatus = .couldNotDetermine
            isAvailable = false
            iCloudAccountSummary = "iCloud unavailable in this build"
            updateStatusLabel()
            return
        }

        do {
            accountStatus = try await container.accountStatus()
            isAvailable = accountStatus == .available
            iCloudAccountSummary = Self.makeAccountSummary(for: accountStatus)
        } catch {
            accountStatus = .couldNotDetermine
            isAvailable = false
            iCloudAccountSummary = "Could not reach iCloud"
        }
        updateStatusLabel()
    }

    /// Kick off another upload attempt after the user taps Retry in Settings.
    func retryBackupAttempt() {
        guard isCloudKitSyncActive, localEntryCount > 0, !hasConfirmedBackup else { return }
        awaitingExportAfterSave = true
        lastBackupError = nil
        isExportInProgress = false
        verificationStep = 0
        beginBackupProgress(at: .savedLocally, progress: 0.2)
        CloudKitSyncKicker.kick()
        scheduleBackupVerification()
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
        if backupPhase == .idle {
            beginBackupProgress(at: .savedLocally, progress: 0.2)
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

    private func handleExportStarted() {
        guard !hasConfirmedBackup else { return }
        isExportInProgress = true
        lastBackupError = nil
        beginBackupProgress(at: .uploading, progress: max(backupProgress, 0.45))
        updateStatusLabel()
    }

    private func handleExportFinished() {
        guard !hasConfirmedBackup, backupPhase != .stalled else { return }
        isExportInProgress = false
        lastBackupError = nil
        beginBackupProgress(at: .confirming, progress: max(backupProgress, 0.85))
        if awaitingExportAfterSave || localEntryCount > 0 {
            confirmBackupFromCloudKit()
        }
    }

    private func handleExportFailed(_ message: String?) {
        guard awaitingExportAfterSave || localEntryCount > 0 else { return }
        verificationTask?.cancel()
        verificationTask = nil
        isExportInProgress = false
        isVerifyingBackup = false
        backupPhase = .stalled
        backupProgress = max(backupProgress, 0.5)
        lastBackupError = message ?? CloudKitUserMessage.backupFailure(from: nil)
        updateStatusLabel()
    }

    private func handleLocalEntrySaved() {
        guard isCloudKitSyncActive, !hasConfirmedBackup else { return }
        awaitingExportAfterSave = true
        lastBackupError = nil
        verificationStep = 0
        if localEntryCount == 0 {
            localEntryCount = 1
        }
        clearStaleNoBackupStateIfNeeded()
        beginBackupProgress(at: .savedLocally, progress: 0.2)
        updateStatusLabel()
        CloudKitSyncKicker.kick()
        scheduleBackupVerification()
    }

    private func confirmBackupFromCloudKit() {
        verificationTask?.cancel()
        verificationTask = nil
        isVerifyingBackup = false
        isExportInProgress = false
        awaitingExportAfterSave = false
        hasConfirmedBackup = true
        lastBackupError = nil
        backupPhase = .backedUp
        backupProgress = 1
        verificationStep = verificationStepCount
        clearStaleNoBackupStateIfNeeded()
        updateStatusLabel()
    }

    private func scheduleBackupVerification() {
        verificationTask?.cancel()
        let retryDelaysSeconds = Self.verificationRetryDelaysSeconds
        verificationStepCount = retryDelaysSeconds.count
        verificationTask = Task {
            isVerifyingBackup = true
            if backupPhase == .savedLocally {
                beginBackupProgress(at: .uploading, progress: max(backupProgress, 0.25))
            }
            updateStatusLabel()

            for (index, delay) in retryDelaysSeconds.enumerated() {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled, localEntryCount > 0, !hasConfirmedBackup else {
                    isVerifyingBackup = false
                    updateStatusLabel()
                    return
                }
                guard backupPhase != .stalled else {
                    isVerifyingBackup = false
                    updateStatusLabel()
                    return
                }

                verificationStep = index + 1
                let confirmingProgress = 0.85 + (Double(index + 1) / Double(retryDelaysSeconds.count)) * 0.14
                beginBackupProgress(at: .confirming, progress: max(backupProgress, confirmingProgress))
                updateStatusLabel()

                if await verifyBackupHandler() {
                    guard backupPhase != .stalled else {
                        isVerifyingBackup = false
                        updateStatusLabel()
                        return
                    }
                    confirmBackupFromCloudKit()
                    return
                }
            }

            isVerifyingBackup = false
            isExportInProgress = false
            if awaitingExportAfterSave, localEntryCount > 0, backupPhase != .stalled {
                backupPhase = .stalled
                backupProgress = max(backupProgress, 0.9)
                lastBackupError =
                    "Upload is taking longer than expected. Stay on Wi‑Fi, keep Ebb open, or tap Retry backup."
            }
            updateStatusLabel()
        }
    }

    private func beginBackupProgress(at phase: CloudBackupPhase, progress: Double) {
        backupPhase = phase
        backupProgress = min(max(progress, 0), 1)
    }

    private static func makeAccountSummary(for status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "Signed in to iCloud on this iPhone"
        case .noAccount:
            return "Not signed in — open Settings → Apple Account → iCloud"
        case .restricted:
            return "iCloud is restricted on this device"
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable"
        case .couldNotDetermine:
            return "Checking iCloud account…"
        @unknown default:
            return "iCloud unavailable"
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
        if hasConfirmedBackup {
            backupPhase = .backedUp
            backupProgress = 1
        } else if localEntryCount == 0, backupPhase != .stalled {
            backupPhase = .idle
            backupProgress = 0
            verificationStep = 0
        }

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
