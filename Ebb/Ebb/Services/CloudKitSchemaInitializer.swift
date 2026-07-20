import CoreData
import Foundation
import SwiftData

/// Ensures the CloudKit schema for SwiftData models is deployed to the server.
/// Without this, TestFlight builds can export locally but never create Production schema.
enum CloudKitSchemaInitializer {
    private static let initializedKey = "ebb.cloudKitSchemaInitialized"

    static func runIfNeeded(
        storageMode: AppStorageMode,
        containerIdentifier: String = CloudSyncStatusService.containerIdentifier
    ) {
        guard storageMode == .cloudKit, AppRuntime.shouldUseCloudKitSync else { return }
        guard !UserDefaults.standard.bool(forKey: initializedKey) else { return }

        do {
            try initializeSchema(containerIdentifier: containerIdentifier)
            UserDefaults.standard.set(true, forKey: initializedKey)
            NSLog("CloudKit schema initialized for \(containerIdentifier)")
        } catch {
            NSLog("CloudKit schema initialization failed: \(error.localizedDescription)")
        }
    }

    private static func initializeSchema(containerIdentifier: String) throws {
        let schema = Schema([SymptomEntry.self])
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private(containerIdentifier)
        )

        try autoreleasepool {
            let storeDescription = NSPersistentStoreDescription(url: configuration.url)
            storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: containerIdentifier
            )
            storeDescription.shouldAddStoreAsynchronously = false

            guard let objectModel = NSManagedObjectModel.makeManagedObjectModel(for: [SymptomEntry.self]) else {
                throw SchemaError.modelUnavailable
            }

            let container = NSPersistentCloudKitContainer(name: "Ebb", managedObjectModel: objectModel)
            container.persistentStoreDescriptions = [storeDescription]

            var loadError: Error?
            container.loadPersistentStores { _, error in
                loadError = error
            }
            if let loadError { throw loadError }

            try container.initializeCloudKitSchema()

            if let store = container.persistentStoreCoordinator.persistentStores.first {
                try container.persistentStoreCoordinator.remove(store)
            }
        }
    }

    private enum SchemaError: Error {
        case modelUnavailable
    }
}
