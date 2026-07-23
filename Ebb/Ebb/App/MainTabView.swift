import SwiftData
import SwiftUI

/// Root tab scaffold: Today · Calendar · Patterns · Settings.
struct MainTabView: View {
    let schema: SchemaConfig
    let schemaLoadResult: Result<SchemaConfig, Error>

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(CloudSyncStatusService.self) private var cloudSyncStatus
    @Query(sort: \SymptomEntry.timestamp, order: .reverse) private var entries: [SymptomEntry]
    @State private var selectedTab = AppTab.today

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

            SettingsView(schemaLoadResult: schemaLoadResult)
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
    .modelContainer(for: SymptomEntry.self, inMemory: true)
}
