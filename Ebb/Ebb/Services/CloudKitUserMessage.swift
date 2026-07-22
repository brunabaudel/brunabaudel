import CloudKit
import Foundation

/// Maps CloudKit errors to copy suitable for Settings backup UI.
enum CloudKitUserMessage {
    static func backupFailure(from error: Error?) -> String {
        guard let error else { return defaultMessage }

        if let ckError = error as? CKError {
            return message(for: ckError.code)
        }

        let nsError = error as NSError
        if nsError.domain == CKErrorDomain,
           let code = CKError.Code(rawValue: nsError.code) {
            return message(for: code)
        }

        return sanitize(error.localizedDescription) ?? defaultMessage
    }

    /// Strips raw CloudKit domain codes from strings already persisted for UI.
    static func sanitize(_ message: String?) -> String? {
        guard let message, !message.isEmpty else { return nil }
        if message.contains("CKErrorDomain") {
            return defaultMessage
        }
        return message
    }

    static func isPartialFailure(_ error: Error?) -> Bool {
        guard let error else { return false }
        if let ckError = error as? CKError {
            return ckError.code == .partialFailure
        }
        let nsError = error as NSError
        return nsError.domain == CKErrorDomain
            && nsError.code == CKError.Code.partialFailure.rawValue
    }

    private static func message(for code: CKError.Code) -> String {
        switch code {
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
            return defaultMessage
        }
    }

    private static let defaultMessage =
        "iCloud upload failed. Stay on Wi‑Fi, keep Ebb open, and tap Retry backup."
}
