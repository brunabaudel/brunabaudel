import CloudKit
import Foundation
import Observation

/// Surfaces the user's iCloud account status for SwiftData + CloudKit sync (Phase 8).
@Observable
@MainActor
final class CloudSyncStatusService {
    static let containerIdentifier = "iCloud.com.bcbs.ebb"

    private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    private(set) var statusLabel: String
    private(set) var isAvailable = false

    private let container: CKContainer?

    init(containerIdentifier: String = CloudSyncStatusService.containerIdentifier) {
        if AppRuntime.shouldUseCloudKitSync {
            container = CKContainer(identifier: containerIdentifier)
            statusLabel = "Checking…"
        } else {
            container = nil
            statusLabel = "On device"
        }
    }

    func refresh() async {
        guard let container else {
            accountStatus = .couldNotDetermine
            isAvailable = false
            statusLabel = "On device"
            return
        }

        do {
            accountStatus = try await container.accountStatus()
            isAvailable = accountStatus == .available
            statusLabel = Self.label(for: accountStatus)
        } catch {
            accountStatus = .couldNotDetermine
            isAvailable = false
            statusLabel = "Unavailable"
        }
    }

    private static func label(for status: CKAccountStatus) -> String {
        switch status {
        case .available: "On · iCloud"
        case .noAccount: "Sign in to iCloud"
        case .restricted: "Restricted"
        case .temporarilyUnavailable: "Temporarily unavailable"
        case .couldNotDetermine: "Checking…"
        @unknown default: "Unavailable"
        }
    }
}
