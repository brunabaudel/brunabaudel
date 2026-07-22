import Foundation
import UIKit

/// Activates CloudKit sync prerequisites on signed device builds.
enum CloudKitSyncBootstrap {
    @MainActor
    static func activateIfNeeded(storageMode: AppStorageMode) {
        guard storageMode == .cloudKit, AppRuntime.shouldUseCloudKitSync else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }
}
