import SwiftUI
import SwiftData

@main
struct EbbApp: App {
    /// Loaded once at launch; the schema is bundled, so failure means a broken
    /// build — surfaced on the debug screen rather than crashing.
    private let schemaLoadResult = Result { try SchemaConfig.load() }
    @State private var cycleService = CycleService()

    var body: some Scene {
        WindowGroup {
            RootView(schemaLoadResult: schemaLoadResult)
                .environment(\.theme, .plumEmber)
                .environment(cycleService)
                .task {
                    await cycleService.refresh()
                }
        }
        .modelContainer(for: SymptomEntry.self)
    }
}

struct RootView: View {
    let schemaLoadResult: Result<SchemaConfig, Error>

    var body: some View {
        switch schemaLoadResult {
        case .success(let schema):
            MainTabView(schema: schema, schemaLoadResult: schemaLoadResult)
        case .failure:
            DebugScreen(schemaLoadResult: schemaLoadResult)
        }
    }
}
