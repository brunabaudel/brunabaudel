import Foundation
import SwiftData

/// Marks symptom entries dirty so SwiftData schedules a CloudKit export.
///
/// Saving an unchanged store often does not enqueue upload work. Bumping
/// `iCloudExportToken` gives CloudKit a real change to push on each nudge.
///
/// Callers must invoke `CloudKitSyncKicker.kick()` separately — this type must
/// not post save/export notifications or it will recurse through `MainTabView`.
enum CloudKitExportNudger {
    @MainActor
    private static var isNudging = false

    @MainActor
    static func nudge(modelContext: ModelContext) {
        guard AppRuntime.shouldUseCloudKitSync else { return }
        guard !isNudging else { return }
        isNudging = true
        defer { isNudging = false }

        let descriptor = FetchDescriptor<SymptomEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        guard let entries = try? modelContext.fetch(descriptor), !entries.isEmpty else {
            try? modelContext.save()
            return
        }

        for entry in entries {
            entry.iCloudExportToken += 1
        }
        try? modelContext.save()
    }
}
