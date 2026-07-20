import Foundation
import SwiftData
import Testing
@testable import Ebb

@Suite("SymptomDataExporter")
@MainActor
struct SymptomDataExporterTests {
    let container: ModelContainer
    let schema = try! SchemaConfig.load(from: .main)

    init() throws {
        container = try ModelContainer(
            for: SymptomEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test func exportDocumentIncludesEntriesAndPreferences() throws {
        let context = ModelContext(container)
        let values = schema.validated(["migraine_present": .boolean(true)])
        context.insert(
            SymptomEntry(
                schemaVersion: schema.schemaVersion,
                fieldValues: values,
                note: "dull ache",
                cyclePhase: .luteal
            )
        )
        try context.save()

        let entries = try context.fetch(FetchDescriptor<SymptomEntry>())
        let preferences = CyclePreferences(defaults: UserDefaults(suiteName: "SymptomDataExporterTests.export")!)
        preferences.typicalCycleLength = 30
        preferences.periodLength = 4
        preferences.hasAura = true

        let document = SymptomDataExporter.makeExportDocument(
            entries: entries,
            schemaVersion: schema.schemaVersion,
            preferences: preferences,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(document.exportVersion == SymptomDataExporter.exportVersion)
        #expect(document.schemaVersion == schema.schemaVersion)
        #expect(document.entries.count == 1)
        #expect(document.entries[0].note == "dull ache")
        #expect(document.entries[0].cyclePhase == .luteal)
        #expect(document.preferences.typicalCycleLength == 30)
        #expect(document.preferences.periodLength == 4)
        #expect(document.preferences.hasAura == true)
    }

    @Test func exportJSONRoundTrips() throws {
        let context = ModelContext(container)
        context.insert(SymptomEntry(schemaVersion: schema.schemaVersion, note: "rough day"))
        try context.save()

        let entries = try context.fetch(FetchDescriptor<SymptomEntry>())
        let preferences = CyclePreferences(defaults: UserDefaults(suiteName: "SymptomDataExporterTests.json")!)
        let data = try SymptomDataExporter.makeJSONData(
            entries: entries,
            schemaVersion: schema.schemaVersion,
            preferences: preferences
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SymptomDataExporter.ExportDocument.self, from: data)
        #expect(decoded.entries.count == 1)
        #expect(decoded.entries[0].note == "rough day")
    }

    @Test func deleteAllDataRemovesEntriesAndResetsPreferences() throws {
        let context = ModelContext(container)
        context.insert(SymptomEntry(schemaVersion: schema.schemaVersion))
        try context.save()

        let preferences = CyclePreferences(defaults: UserDefaults(suiteName: "SymptomDataExporterTests.delete")!)
        preferences.typicalCycleLength = 33
        preferences.hasAura = true

        try SymptomDataExporter.deleteAllData(modelContext: context, preferences: preferences)

        let remaining = try context.fetch(FetchDescriptor<SymptomEntry>())
        #expect(remaining.isEmpty)
        #expect(preferences.typicalCycleLength == CyclePreferences.defaultCycleLength)
        #expect(preferences.periodLength == CyclePreferences.defaultPeriodLength)
        #expect(preferences.hasAura == false)
    }
}

@Suite("AppLockController")
@MainActor
struct AppLockControllerTests {
    @Test func startsLockedWhenEnabled() {
        let defaults = UserDefaults(suiteName: "AppLockControllerTests.enabled")!
        defaults.set(true, forKey: "ebb.privacy.appLockEnabled")

        let controller = AppLockController(defaults: defaults)
        #expect(controller.isEnabled == true)
        #expect(controller.isLocked == true)
    }

    @Test func disablingUnlocksImmediately() {
        let defaults = UserDefaults(suiteName: "AppLockControllerTests.disable")!
        defaults.set(true, forKey: "ebb.privacy.appLockEnabled")

        let controller = AppLockController(defaults: defaults)
        controller.isEnabled = false

        #expect(controller.isEnabled == false)
        #expect(controller.isLocked == false)
    }

    @Test func backgroundPhaseLocksWhenEnabled() {
        let defaults = UserDefaults(suiteName: "AppLockControllerTests.background")!
        defaults.set(true, forKey: "ebb.privacy.appLockEnabled")

        let controller = AppLockController(defaults: defaults)
        controller.unlock()
        controller.handleScenePhase(.background)

        #expect(controller.isLocked == true)
    }

    @Test func healthKitAuthorizationFlowSkipsBackgroundLock() {
        let defaults = UserDefaults(suiteName: "AppLockControllerTests.healthKitFlow")!
        defaults.set(true, forKey: "ebb.privacy.appLockEnabled")

        let controller = AppLockController(defaults: defaults)
        controller.unlock()
        controller.beginHealthKitAuthorizationFlow()
        controller.handleScenePhase(.background)

        #expect(controller.isLocked == false)
        #expect(controller.isPermissionFlowActive == true)

        controller.endPermissionFlow()
        controller.handleScenePhase(.background)

        #expect(controller.isLocked == true)
    }

    @Test func externalHealthAppFlowEndsOnActiveWithoutAutoLock() {
        let defaults = UserDefaults(suiteName: "AppLockControllerTests.healthAppFlow")!
        defaults.set(true, forKey: "ebb.privacy.appLockEnabled")

        let controller = AppLockController(defaults: defaults)
        controller.unlock()
        controller.beginExternalHealthAppFlow()
        controller.handleScenePhase(.background)

        #expect(controller.isLocked == false)
        controller.handleScenePhase(.active)

        #expect(controller.isPermissionFlowActive == false)
        #expect(controller.isLocked == false)
    }
}
