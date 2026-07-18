import SwiftUI
import SwiftData

@main
struct EbbApp: App {
    /// Loaded once at launch; the schema is bundled, so failure means a broken
    /// build — surfaced on the debug screen rather than crashing.
    private let schemaLoadResult = Result { try SchemaConfig.load() }
    @State private var cycleService = Self.makeCycleService()
    @State private var speechCapture = Self.makeSpeechCapture()
    @State private var appLock = AppLockController()
    @State private var cloudSyncStatus = CloudSyncStatusService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(schemaLoadResult: schemaLoadResult)
                .environment(\.theme, .plumEmber)
                .environment(cycleService)
                .environment(speechCapture)
                .environment(appLock)
                .environment(cloudSyncStatus)
                .environment(\.symptomClassifier, Self.makeSymptomClassifier())
                .overlay {
                    if appLock.isLocked && !Self.isRunningTests {
                        AppLockOverlay()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard !Self.isRunningTests else { return }
                    appLock.handleScenePhase(newPhase)
                }
                .task {
                    guard !Self.isRunningTests else { return }
                    await cycleService.refresh()
                    if AppRuntime.shouldUseCloudKitSync {
                        await cloudSyncStatus.refresh()
                    }
                }
        }
        .modelContainer(Self.modelContainer)
    }

    private static var isRunningTests: Bool {
        AppRuntime.isRunningTests
    }

    private static let modelContainer: ModelContainer = {
        do {
            let schema = Schema([SymptomEntry.self])
            if isRunningTests {
                return try ModelContainer(
                    for: schema,
                    configurations: ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: true
                    )
                )
            }
            if AppRuntime.shouldUseCloudKitSync {
                return try ModelContainer(
                    for: schema,
                    configurations: ModelConfiguration(
                        schema: schema,
                        cloudKitDatabase: .private(CloudSyncStatusService.containerIdentifier)
                    )
                )
            }
            return try ModelContainer(for: schema)
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

    private static func makeSymptomClassifier() -> any SymptomClassifier {
        if isRunningTests {
            return SynonymSymptomClassifier()
        }
        return SymptomClassifierFactory.makeDefault()
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
