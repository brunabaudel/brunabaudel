import SwiftUI
import SwiftData

@main
struct EbbApp: App {
    /// Loaded once at launch; the schema is bundled, so failure means a broken
    /// build — surfaced on the debug screen rather than crashing.
    private let schemaLoadResult = Result { try SchemaConfig.load() }
    @State private var cycleService = Self.makeCycleService()
    @State private var speechCapture = Self.makeSpeechCapture()

    var body: some Scene {
        WindowGroup {
            RootView(schemaLoadResult: schemaLoadResult)
                .environment(\.theme, .plumEmber)
                .environment(cycleService)
                .environment(speechCapture)
                .task {
                    guard !Self.isRunningTests else { return }
                    await cycleService.refresh()
                }
        }
        .modelContainer(Self.modelContainer)
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private static let modelContainer: ModelContainer = {
        do {
            if isRunningTests {
                return try ModelContainer(
                    for: SymptomEntry.self,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                )
            }
            return try ModelContainer(for: SymptomEntry.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    private static func makeCycleService() -> CycleService {
        if isRunningTests {
            return CycleService(provider: MockCycleDataProvider())
        }
        return CycleService()
    }

    private static func makeSpeechCapture() -> SpeechCapture {
        if isRunningTests {
            return SpeechCapture(provider: MockSpeechRecognizer(transcript: ""))
        }
        return SpeechCapture()
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
