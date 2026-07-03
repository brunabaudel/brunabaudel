import SwiftUI
import SwiftData

@main
struct EbbApp: App {
    /// Loaded once at launch; the schema is bundled, so failure means a broken
    /// build — surfaced on the debug screen rather than crashing.
    private let schemaLoadResult = Result { try SchemaConfig.load() }

    var body: some Scene {
        WindowGroup {
            RootView(schemaLoadResult: schemaLoadResult)
                .environment(\.theme, .plumEmber)
        }
        .modelContainer(for: SymptomEntry.self)
    }
}

/// Phase 0 root: just the debug screen. Replaced by the tab scaffold in Phase 1.
struct RootView: View {
    let schemaLoadResult: Result<SchemaConfig, Error>

    var body: some View {
        DebugScreen(schemaLoadResult: schemaLoadResult)
    }
}
