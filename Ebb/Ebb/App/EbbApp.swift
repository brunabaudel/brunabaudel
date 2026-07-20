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

    private static let modelContainer: ModelContainer = makeModelContainer()

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([SymptomEntry.self])

        if isRunningTests {
            return (try? ModelContainer(
                for: schema,
                configurations: ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
            )) ?? inMemoryContainer(schema: schema)
        }

        if AppRuntime.shouldUseCloudKitSync {
            let cloudConfiguration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private(CloudSyncStatusService.containerIdentifier)
            )
            if let container = try? ModelContainer(for: schema, configurations: cloudConfiguration) {
                return container
            }
            NSLog("CloudKit ModelContainer unavailable, falling back to local SwiftData storage.")
        }

        let localConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        if let container = try? ModelContainer(for: schema, configurations: localConfiguration) {
            return container
        }

        NSLog("Persistent SwiftData store unavailable, using in-memory fallback.")
        return inMemoryContainer(schema: schema)
    }

    private static func inMemoryContainer(schema: Schema) -> ModelContainer {
        guard let container = try? ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        ) else {
            preconditionFailure("In-memory SwiftData container must always succeed.")
        }
        return container
    }

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
