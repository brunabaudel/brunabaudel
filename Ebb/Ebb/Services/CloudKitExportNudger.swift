import Foundation
import SwiftData

/// Marks one symptom entry dirty so SwiftData can schedule a CloudKit export.
///
/// Only invoked on explicit user retry — automatic saves already enqueue export.
/// Bumping every entry repeatedly caused BGSystemTaskScheduler export conflicts.
enum CloudKitExportNudger {
    @MainActor
    private static var isNudging = false

    @MainActor
    static func nudge(modelContext: ModelContext) {
        guard AppRuntime.shouldUseCloudKitSync else { return }
        guard !isNudging else { return }

        isNudging = true
        defer { isNudging = false }

        var descriptor = FetchDescriptor<SymptomEntry>(
            sortBy: [SortDescriptor(\SymptomEntry.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        guard let entry = try? modelContext.fetch(descriptor).first else {
            try? modelContext.save()
            return
        }

        entry.iCloudExportToken += 1
        try? modelContext.save()
    }
}
