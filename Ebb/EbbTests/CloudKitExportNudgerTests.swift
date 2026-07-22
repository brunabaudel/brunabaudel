import Foundation
import SwiftData
import Testing
@testable import Ebb

@Suite("CloudKit export nudge")
@MainActor
struct CloudKitExportNudgerTests {
    let container: ModelContainer
    let schema = try! SchemaConfig.load(from: .main)

    init() throws {
        container = try ModelContainer(
            for: SymptomEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test func kickDoesNotRepostLocalSaveNotification() {
        var localSaveCount = 0
        let token = NotificationCenter.default.addObserver(
            forName: .ebbLocalEntrySaved,
            object: nil,
            queue: nil
        ) { _ in
            localSaveCount += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }

        CloudKitSyncKicker.kick()

        #expect(localSaveCount == 0)
    }

    @Test func nudgeBumpsExportTokenWithoutRepostingLocalSave() throws {
        let context = ModelContext(container)
        let entry = SymptomEntry(schemaVersion: schema.schemaVersion, note: "test")
        context.insert(entry)
        try context.save()
        #expect(entry.iCloudExportToken == 0)

        var localSaveCount = 0
        let token = NotificationCenter.default.addObserver(
            forName: .ebbLocalEntrySaved,
            object: nil,
            queue: nil
        ) { _ in
            localSaveCount += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }

        AppRuntime.forceCloudKitSyncForTesting = true
        defer { AppRuntime.forceCloudKitSyncForTesting = false }

        CloudKitExportNudger.nudge(modelContext: context)

        #expect(entry.iCloudExportToken == 1)
        #expect(localSaveCount == 0)
    }
}
