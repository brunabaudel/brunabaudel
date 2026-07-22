import Foundation
import SwiftData

/// The cycle phase stamped on an entry at save time. Derived from HealthKit
/// (Phase 4) — never entered by the user.
enum CyclePhase: String, Codable, CaseIterable, Sendable {
    case menstrual
    case follicular
    case ovulation
    case luteal
}

/// One logged moment: what the user said (or tapped) plus derived context.
///
/// CloudKit-compatible by construction (build-plan Phase 0): every stored
/// property is optional or defaulted, and nothing is `@Attribute(.unique)`.
/// Field values are persisted as the schema's canonical JSON, keyed by the
/// `schemaVersion` they were validated against, so old entries still resolve
/// when the enum set grows.
@Model
final class SymptomEntry {
    var timestamp: Date = Date()
    var schemaVersion: String = ""
    /// JSON-encoded `[String: FieldValue]`. Stored as raw data rather than a
    /// transformable dictionary so migration stays a pure JSON concern.
    var fieldValuesData: Data = Data()
    /// Internal counter bumped to force CloudKit re-export. Never shown in UI.
    var iCloudExportToken: Int = 0
    /// Verbatim transcript or typed note. Never rewritten (spec: the user's
    /// own words are kept so they can re-read them).
    var note: String?
    private var cyclePhaseRawValue: String?

    init(
        timestamp: Date = .now,
        schemaVersion: String,
        fieldValues: [String: FieldValue] = [:],
        note: String? = nil,
        cyclePhase: CyclePhase? = nil
    ) {
        self.timestamp = timestamp
        self.schemaVersion = schemaVersion
        self.fieldValuesData = Self.encode(fieldValues)
        self.note = note
        self.cyclePhaseRawValue = cyclePhase?.rawValue
    }
}

extension SymptomEntry {
    var cyclePhase: CyclePhase? {
        get { cyclePhaseRawValue.flatMap(CyclePhase.init(rawValue:)) }
        set { cyclePhaseRawValue = newValue?.rawValue }
    }

    var fieldValues: [String: FieldValue] {
        get {
            (try? JSONDecoder().decode([String: FieldValue].self, from: fieldValuesData)) ?? [:]
        }
        set {
            fieldValuesData = Self.encode(newValue)
        }
    }

    private static func encode(_ values: [String: FieldValue]) -> Data {
        // Encoding [String: FieldValue] cannot fail: keys are strings and
        // every FieldValue case encodes to a JSON primitive or string array.
        (try? JSONEncoder().encode(values)) ?? Data()
    }
}
