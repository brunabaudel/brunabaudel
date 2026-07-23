import Foundation
import SwiftData

/// JSON export and destructive wipe for user-owned data (build-plan Phase 8).
enum SymptomDataExporter {
    static let exportVersion = 1

    struct ExportDocument: Codable, Equatable, Sendable {
        let exportVersion: Int
        let exportedAt: Date
        let schemaVersion: String
        let entries: [ExportEntry]
        let preferences: ExportPreferences
    }

    struct ExportEntry: Codable, Equatable, Sendable {
        let timestamp: Date
        let schemaVersion: String
        let note: String?
        let cyclePhase: CyclePhase?
        let fieldValues: [String: FieldValue]
    }

    struct ExportPreferences: Codable, Equatable, Sendable {
        let typicalCycleLength: Int
        let periodLength: Int
        let hasAura: Bool
    }

    static func makeExportDocument(
        entries: [SymptomEntry],
        schemaVersion: String,
        preferences: CyclePreferences,
        exportedAt: Date = .now
    ) -> ExportDocument {
        ExportDocument(
            exportVersion: exportVersion,
            exportedAt: exportedAt,
            schemaVersion: schemaVersion,
            entries: entries.map(ExportEntry.init(entry:)),
            preferences: ExportPreferences(preferences: preferences)
        )
    }

    static func makeJSONData(
        entries: [SymptomEntry],
        schemaVersion: String,
        preferences: CyclePreferences,
        exportedAt: Date = .now
    ) throws -> Data {
        let document = makeExportDocument(
            entries: entries,
            schemaVersion: schemaVersion,
            preferences: preferences,
            exportedAt: exportedAt
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    static func makeTemporaryExportFile(
        entries: [SymptomEntry],
        schemaVersion: String,
        preferences: CyclePreferences
    ) throws -> URL {
        let data = try makeJSONData(
            entries: entries,
            schemaVersion: schemaVersion,
            preferences: preferences
        )
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let stamp = formatter.string(from: .now)
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ebb-export-\(stamp).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    @MainActor
    static func deleteAllData(
        modelContext: ModelContext,
        preferences: CyclePreferences,
        medicationPreferences: MedicationPreferences? = nil,
        reminderPreferences: ReminderPreferences? = nil
    ) throws {
        try modelContext.delete(model: SymptomEntry.self)
        try modelContext.save()
        preferences.resetToDefaults()
        medicationPreferences?.resetToDefaults()
        reminderPreferences?.resetToDefaults()
    }
}

private extension SymptomDataExporter.ExportEntry {
    init(entry: SymptomEntry) {
        timestamp = entry.timestamp
        schemaVersion = entry.schemaVersion
        note = entry.note
        cyclePhase = entry.cyclePhase
        fieldValues = entry.fieldValues
    }
}

private extension SymptomDataExporter.ExportPreferences {
    init(preferences: CyclePreferences) {
        typicalCycleLength = preferences.typicalCycleLength
        periodLength = preferences.periodLength
        hasAura = preferences.hasAura
    }
}

extension CyclePreferences {
    func resetToDefaults() {
        typicalCycleLength = Self.defaultCycleLength
        periodLength = Self.defaultPeriodLength
        hasAura = false
    }
}
