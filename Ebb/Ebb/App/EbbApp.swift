import SwiftUI
import SwiftData

@main
struct EbbApp: App {
    @UIApplicationDelegateAdaptor(EbbAppDelegate.self) private var appDelegate
    /// Loaded once at launch; the schema is bundled, so failure means a broken
    /// build — surfaced on the debug screen rather than crashing.
    private let schemaLoadResult = Result { try SchemaConfig.load() }
    @State private var cycleService = Self.makeCycleService()
    @State private var speechCapture = Self.makeSpeechCapture()
    @State private var appLock = AppLockController()
    @State private var cloudSyncStatus = CloudSyncStatusService(
        storageMode: Self.storageBootstrap.storageMode
    )
    @State private var entitlements = EntitlementsService(listenForUpdates: !Self.isRunningTests)
    @State private var themePreferences = ThemePreferences()
    @State private var onboardingPreferences = OnboardingPreferences()
    @State private var medicationPreferences = MedicationPreferences()
    @State private var reminderPreferences = ReminderPreferences()

    var body: some Scene {
        WindowGroup {
            AppLockGate {
                ThemeHost {
                    RootView(schemaLoadResult: schemaLoadResult)
                }
                    .environment(cycleService)
                    .environment(speechCapture)
                    .environment(appLock)
                    .environment(cloudSyncStatus)
                    .environment(entitlements)
                    .environment(themePreferences)
                    .environment(onboardingPreferences)
                    .environment(medicationPreferences)
                    .environment(reminderPreferences)
                    .environment(\.symptomClassifier, Self.makeSymptomClassifier())
            }
            .environment(appLock)
            .task {
                guard !Self.isRunningTests else { return }
                CloudKitSyncBootstrap.activateIfNeeded(
                    storageMode: Self.storageBootstrap.storageMode
                )
                await cycleService.refresh()
                await cloudSyncStatus.refresh()
                await entitlements.bootstrap()
            }
        }
        .modelContainer(Self.storageBootstrap.container)
    }

    private static var isRunningTests: Bool {
        AppRuntime.isRunningTests
    }

    private static let storageBootstrap = StorageBootstrap.make(
        isRunningTests: AppRuntime.isRunningTests
    )

    private static func makeCycleService() -> CycleService {
        if isRunningTests {
            return CycleService(provider: MockCycleDataProvider())
        }
        if ProcessInfo.processInfo.hasLaunchArgumentMockLutealStartToday {
            return CycleService(provider: MockCycleDataProvider.lutealStartTodaySample())
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
