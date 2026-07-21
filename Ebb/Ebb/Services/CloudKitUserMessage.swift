import CloudKit
import Foundation

/// Maps CloudKit errors to copy suitable for Settings backup UI.
enum CloudKitUserMessage {
    static func backupFailure(from error: Error?) -> String {
        guard let error else { return defaultMessage }

        if let ckError = error as? CKError {
            switch ckError.code {
            case .partialFailure:
                return "iCloud couldn't finish uploading all of your logs. Stay on Wi‑Fi, keep Ebb open, and tap Retry backup."
            case .networkUnavailable, .networkFailure:
                return "iCloud isn't reachable right now. Connect to Wi‑Fi and try again."
            case .serviceUnavailable, .requestRateLimited, .zoneBusy:
                return "iCloud is busy right now. Wait a minute, then tap Retry backup."
            case .notAuthenticated, .permissionFailure:
                return "Sign in to iCloud in Settings, then tap Retry backup."
            case .quotaExceeded:
                return "Your iCloud storage is full. Free up space in Settings, then tap Retry backup."
            default:
                break
            }
        }

        let description = error.localizedDescription
        if description.contains("CKErrorDomain") {
            return defaultMessage
        }
        return description
    }

    private static let defaultMessage =
        "iCloud upload failed. Stay on Wi‑Fi, keep Ebb open, and tap Retry backup."
}
