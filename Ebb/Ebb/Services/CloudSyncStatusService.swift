import CloudKit
import Foundation
import Observation

/// Surfaces the user's iCloud account status for SwiftData + CloudKit sync (Phase 8).
@Observable
@MainActor
final class CloudSyncStatusService {
    static let containerIdentifier = "iCloud.com.bcbs.ebb"

    private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    private(set) var statusLabel = "Checking…"
    private(set) var isAvailable = false

    private let container: CKContainer

    init(container: CKContainer = CKContainer(identifier: CloudSyncStatusService.containerIdentifier)) {
        self.container = container
    }

    func refresh() async {
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
