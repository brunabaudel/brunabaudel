import Foundation
import SwiftData
import Testing
@testable import Ebb

@Suite("SymptomEntry persistence")
@MainActor
struct SymptomEntryTests {
    let container: ModelContainer
    let schema = try! SchemaConfig.load(from: .main)

    init() throws {
        container = try ModelContainer(
            for: SymptomEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test func roundTripsThroughSwiftData() throws {
        let values = schema.validated([
            "migraine_present": .boolean(true),
            "severity": .scale(2),
            "location": .choices(["left", "behind_eye"]),
            "bleeding": .choice("spotting"),
        ])
        let context = ModelContext(container)
        let entry = SymptomEntry(
            schemaVersion: schema.schemaVersion,
            fieldValues: values,
            note: "pounding behind my left eye",
            cyclePhase: .menstrual
        )
        context.insert(entry)
        try context.save()

        let fetched = try #require(try ModelContext(container).fetch(FetchDescriptor<SymptomEntry>()).first)
        #expect(fetched.fieldValues == values)
        #expect(fetched.schemaVersion == schema.schemaVersion)
        #expect(fetched.note == "pounding behind my left eye")
        #expect(fetched.cyclePhase == .menstrual)
    }

    @Test func emptyEntryPersists() throws {
        let context = ModelContext(container)
        context.insert(SymptomEntry(schemaVersion: schema.schemaVersion))
        try context.save()

        let fetched = try #require(try ModelContext(container).fetch(FetchDescriptor<SymptomEntry>()).first)
        #expect(fetched.fieldValues.isEmpty)
        #expect(fetched.note == nil)
        #expect(fetched.cyclePhase == nil)
    }

    @Test func fieldValuesAreMutableAfterInit() throws {
        let entry = SymptomEntry(schemaVersion: schema.schemaVersion)
        entry.fieldValues = ["cramps_severity": .scale(3)]
        #expect(entry.fieldValues == ["cramps_severity": .scale(3)])
    }

    @Test func storageRoundTripCheckPasses() {
        #expect(StorageRoundTripCheck.run(in: container, schema: schema) == .passed)
    }
}
