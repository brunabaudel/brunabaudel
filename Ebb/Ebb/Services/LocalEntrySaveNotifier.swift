import Foundation

/// Posted immediately after a symptom entry is saved locally, before `@Query` refreshes.
enum LocalEntrySaveNotifier {
    static func notifySaved() {
        NotificationCenter.default.post(name: .ebbLocalEntrySaved, object: nil)
    }
}

extension Notification.Name {
    static let ebbLocalEntrySaved = Notification.Name("ebb.localEntrySaved")
    static let ebbCloudKitExportStarted = Notification.Name("ebb.cloudKitExportStarted")
    static let ebbCloudKitExportFailed = Notification.Name("ebb.cloudKitExportFailed")
}
