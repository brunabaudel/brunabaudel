import UIKit

/// Nudges CloudKit sync when uploads appear stuck. There is no public API to force export;
/// re-registering for silent push and saving the store are the best levers available.
enum CloudKitSyncKicker {
    static func kick() {
        guard AppRuntime.shouldUseCloudKitSync else { return }
        UIApplication.shared.registerForRemoteNotifications()
        NotificationCenter.default.post(name: .ebbRequestCloudKitExport, object: nil)
    }
}
