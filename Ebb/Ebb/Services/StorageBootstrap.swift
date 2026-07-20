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
            if let container = try? ModelContainer(for: schema, configurations: cloudConfiguration) {
                CloudKitImportObserver.register()
                return Result(container: container, storageMode: .cloudKit)
            }
            NSLog("CloudKit ModelContainer unavailable, falling back to local SwiftData storage.")
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

/// Listens for CloudKit import completion so restore UI can finish promptly.
enum CloudKitImportObserver {
    static func register() {
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard
                let event = notification.userInfo?[
                    NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                ] as? NSPersistentCloudKitContainer.Event,
                event.type == .import,
                event.endDate != nil
            else {
                return
            }

            NotificationCenter.default.post(name: .ebbCloudKitImportFinished, object: nil)
        }
    }
}

extension Notification.Name {
    static let ebbCloudKitImportFinished = Notification.Name("ebb.cloudKitImportFinished")
}
