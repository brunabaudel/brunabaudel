import UIKit

/// Requests a CloudKit export nudge. SwiftData schedules export automatically on save;
/// only force a token bump when the user explicitly retries a stalled backup.
enum CloudKitSyncKicker {
    @MainActor
    private static var didRegisterForRemoteNotifications = false

    @MainActor
    static func kick(force: Bool = false) {
        guard AppRuntime.shouldUseCloudKitSync else { return }

        if !didRegisterForRemoteNotifications {
            didRegisterForRemoteNotifications = true
            UIApplication.shared.registerForRemoteNotifications()
        }

        guard force else { return }

        NotificationCenter.default.post(
            name: .ebbRequestCloudKitExport,
            object: nil,
            userInfo: [Self.forceUserInfoKey: true]
        )
    }

    static let forceUserInfoKey = "force"

    #if DEBUG
    @MainActor
    static func resetForTesting() {
        didRegisterForRemoteNotifications = false
    }
    #endif
}
