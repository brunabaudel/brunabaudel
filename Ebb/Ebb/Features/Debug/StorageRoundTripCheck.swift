import Foundation
import SwiftData

/// Phase 0 acceptance check: a `SymptomEntry` written through SwiftData comes
/// back intact. Lives outside the view so the debug screen stays dumb and the
/// same check runs in unit tests.
enum StorageRoundTripCheck {
    enum Outcome: Equatable {
        case passed
        case failed(String)
    }

    /// Sample values exercising all four field shapes; validated against the
    /// schema before writing so the check also covers the validation gate.
    static func sampleValues(for schema: SchemaConfig) -> [String: FieldValue] {
        schema.validated([
            "migraine_present": .boolean(true),
            "severity": .scale(3),
            "bleeding": .choice("light"),
            "location": .choices(["right", "temple"]),
        ])
    }

    @MainActor
    static func run(in container: ModelContainer, schema: SchemaConfig) -> Outcome {
        let writeContext = ModelContext(container)
        let written = SymptomEntry(
            schemaVersion: schema.schemaVersion,
            fieldValues: sampleValues(for: schema),
            note: "round-trip check",
            cyclePhase: .luteal
        )
        writeContext.insert(written)

        do {
            try writeContext.save()
            defer {
                writeContext.delete(written)
                try? writeContext.save()
            }

            // A separate context guarantees the fetch reads from the store
            // instead of returning the in-memory object just inserted.
            let id = written.persistentModelID
            let fetchedAll = try ModelContext(container).fetch(FetchDescriptor<SymptomEntry>())
            guard let fetched = fetchedAll.first(where: { $0.persistentModelID == id }) else {
                return .failed("Saved entry not found on fetch")
            }

            guard fetched.fieldValues == sampleValues(for: schema) else {
                return .failed("Field values changed across save/fetch")
            }
            guard fetched.schemaVersion == schema.schemaVersion,
                  fetched.cyclePhase == .luteal,
                  fetched.note == "round-trip check" else {
                return .failed("Metadata changed across save/fetch")
            }
            return .passed
        } catch {
            return .failed("SwiftData error: \(error.localizedDescription)")
        }
    }
}
