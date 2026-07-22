import Foundation
import SwiftData

/// Marks symptom entries dirty so SwiftData schedules a CloudKit export.
///
/// Saving an unchanged store often does not enqueue upload work. Bumping
/// `iCloudExportToken` gives CloudKit a real change to push on each nudge.
enum CloudKitExportNudger {
    @MainActor
    static func nudge(modelContext: ModelContext) {
        guard AppRuntime.shouldUseCloudKitSync else { return }

        let descriptor = FetchDescriptor<SymptomEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        guard let entries = try? modelContext.fetch(descriptor), !entries.isEmpty else {
            try? modelContext.save()
            CloudKitSyncKicker.kick()
            return
        }

        for entry in entries {
            entry.iCloudExportToken += 1
        }
        try? modelContext.save()
        LocalEntrySaveNotifier.notifySaved()
        CloudKitSyncKicker.kick()
    }
}
