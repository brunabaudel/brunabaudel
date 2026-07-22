import CoreData
import Foundation
import SwiftData

/// How symptom entries are persisted for this app launch.
enum AppStorageMode: Equatable, Sendable {
    case cloudKit
    case localByChoice
    case localFallback
    case inMemoryFallback
    case inMemoryTesting
}

enum StorageBootstrap {
    struct Result {
        let container: ModelContainer
        let storageMode: AppStorageMode
    }

    static func make(isRunningTests: Bool) -> Result {
        let schema = Schema([SymptomEntry.self])

        if isRunningTests {
            return Result(
                container: inMemoryContainer(schema: schema),
                storageMode: .inMemoryTesting
            )
        }

        let syncPreferences = SyncPreferences()

        if !syncPreferences.iCloudSyncEnabled {
            if let container = localPersistentContainer(schema: schema) {
                return Result(container: container, storageMode: .localByChoice)
            }
            return Result(
                container: inMemoryContainer(schema: schema),
                storageMode: .inMemoryFallback
            )
        }

        if AppRuntime.shouldUseCloudKitSync {
            let cloudConfiguration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private(CloudSyncStatusService.containerIdentifier)
            )
            do {
                let container = try ModelContainer(for: schema, configurations: cloudConfiguration)
                CloudKitSyncObserver.register()
                return Result(container: container, storageMode: .cloudKit)
            } catch {
                NSLog("CloudKit ModelContainer unavailable: \(error.localizedDescription)")
            }
        }

        if let container = localPersistentContainer(schema: schema) {
            return Result(container: container, storageMode: .localFallback)
        }

        return Result(
            container: inMemoryContainer(schema: schema),
            storageMode: .inMemoryFallback
        )
    }

    // MARK: - Private

    private static var localStoreURL: URL {
        URL.applicationSupportDirectory.appending(path: "ebb-local.store")
    }

    private static func localPersistentContainer(schema: Schema) -> ModelContainer? {
        try? ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                schema: schema,
                url: localStoreURL,
                cloudKitDatabase: .none
            )
        )
    }

    private static func inMemoryContainer(schema: Schema) -> ModelContainer {
        guard let container = try? ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        ) else {
            preconditionFailure("In-memory SwiftData container must always succeed.")
        }
        return container
    }
}

/// Listens for CloudKit import/export events so restore and backup UI stay honest.
enum CloudKitSyncObserver {
    static func register() {
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard
                let event = notification.userInfo?[
                    NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                ] as? NSPersistentCloudKitContainer.Event
            else {
                return
            }

            if event.endDate == nil {
                switch event.type {
                case .export:
                    NotificationCenter.default.post(name: .ebbCloudKitExportStarted, object: nil)
                default:
                    break
                }
                return
            }

            switch event.type {
            case .import:
                NotificationCenter.default.post(name: .ebbCloudKitImportFinished, object: nil)
            case .export:
                if event.succeeded {
                    NotificationCenter.default.post(name: .ebbCloudKitExportFinished, object: nil)
                } else {
                    let underlyingError = event.error
                    let message = CloudKitUserMessage.backupFailure(from: underlyingError)
                    let isPartialFailure = CloudKitUserMessage.isPartialFailure(underlyingError)
                    NSLog(
                        "CloudKit export failed: %@",
                        underlyingError?.localizedDescription ?? message
                    )
                    NotificationCenter.default.post(
                        name: .ebbCloudKitExportFailed,
                        object: nil,
                        userInfo: [
                            "error": message,
                            "isPartialFailure": isPartialFailure,
                        ]
                    )
                }
            default:
                break
            }
        }
    }
}

extension Notification.Name {
    static let ebbCloudKitImportFinished = Notification.Name("ebb.cloudKitImportFinished")
    static let ebbCloudKitExportFinished = Notification.Name("ebb.cloudKitExportFinished")
}
