import SwiftData
import SwiftUI

/// Root tab scaffold: Today · Calendar · Patterns · Settings.
struct MainTabView: View {
    let schema: SchemaConfig
    let schemaLoadResult: Result<SchemaConfig, Error>

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(CloudSyncStatusService.self) private var cloudSyncStatus
    @Environment(CycleService.self) private var cycleService
    @Environment(OnboardingPreferences.self) private var onboardingPreferences
    @Environment(ReminderPreferences.self) private var reminderPreferences
    @Query(sort: \SymptomEntry.timestamp, order: .reverse) private var entries: [SymptomEntry]
    @State private var selectedTab = AppTab.today
    @State private var onboardingViewModel = OnboardingViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(schema: schema)
                .tag(AppTab.today)
                .tabItem {
                    Label("Today", systemImage: "sun.max")
                }

            CalendarView(schema: schema)
                .tag(AppTab.calendar)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            PatternsView(schema: schema)
                .tag(AppTab.patterns)
                .tabItem {
                    Label("Patterns", systemImage: "chart.line.uptrend.xyaxis")
                }

            SettingsView(schema: schema, schemaLoadResult: schemaLoadResult)
                .tag(AppTab.settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(theme.pain)
        .safeAreaInset(edge: .top, spacing: 0) {
            if cloudSyncStatus.restorePhase == .restoring {
                CloudRestoreBanner()
            }
        }
        .onAppear {
            if ProcessInfo.processInfo.hasLaunchArgumentOpenTabCalendar {
                selectedTab = .calendar
            }
            cloudSyncStatus.noteEntryCount(entries.count)
            cloudSyncStatus.monitorRestore(entryCount: entries.count)
        }
        .onChange(of: cloudSyncStatus.isAvailable) { _, isAvailable in
            if isAvailable {
                cloudSyncStatus.noteEntryCount(entries.count)
                cloudSyncStatus.monitorRestore(entryCount: entries.count)
            }
        }
        .onChange(of: cloudSyncStatus.importFinishedGeneration) { _, _ in
            cloudSyncStatus.monitorRestore(entryCount: entries.count)
        }
        .onChange(of: entries.count) { _, entryCount in
            cloudSyncStatus.noteEntryCount(entryCount)
            cloudSyncStatus.monitorRestore(entryCount: entryCount)
        }
        .onReceive(NotificationCenter.default.publisher(for: .ebbRequestCloudKitExport)) { _ in
            CloudKitExportNudger.nudge(modelContext: modelContext)
        }
        .fullScreenCover(isPresented: showOnboarding) {
            OnboardingView(
                viewModel: onboardingViewModel,
                onboardingPreferences: onboardingPreferences
            )
        }
        .task {
            await rescheduleReminders()
        }
        .onChange(of: entries.count) { _, _ in
            Task { await rescheduleReminders() }
        }
        .onChange(of: cycleService.lastRefreshed) { _, _ in
            Task { await rescheduleReminders() }
        }
    }

    private var showOnboarding: Binding<Bool> {
        Binding(
            get: { !onboardingPreferences.hasCompletedOnboarding },
            set: { isPresented in
                if !isPresented {
                    onboardingPreferences.markCompleted()
                }
            }
        )
    }

    private func rescheduleReminders() async {
        guard onboardingPreferences.hasCompletedOnboarding else { return }
        let overlay = cycleService.makeOverlay(from: entries)
        await ReminderScheduler.reschedule(
            input: ReminderScheduler.ScheduleInput(
                preferences: reminderPreferences,
                overlay: overlay,
                entries: entries,
                now: .now
            )
        )
    }
}

private enum AppTab: Int {
    case today
    case calendar
    case patterns
    case settings
}

#Preview {
    MainTabView(
        schema: try! SchemaConfig.load(),
        schemaLoadResult: Result { try SchemaConfig.load() }
    )
    .environment(\.theme, .plumEmber)
    .environment(CloudSyncStatusService(storageMode: .cloudKit))
    .environment(CycleService(provider: MockCycleDataProvider()))
    .environment(EntitlementsService(previewIsEbbPlus: false, listenForUpdates: false))
    .environment(ThemePreferences())
    .environment(OnboardingPreferences())
    .environment(MedicationPreferences())
    .environment(ReminderPreferences())
    .modelContainer(for: SymptomEntry.self, inMemory: true)
}
