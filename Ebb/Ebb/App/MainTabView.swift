import SwiftUI

/// Root tab scaffold: Today · Calendar · Patterns · Settings.
struct MainTabView: View {
    let schema: SchemaConfig
    let schemaLoadResult: Result<SchemaConfig, Error>

    @Environment(\.theme) private var theme
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

            PatternsView()
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
        .onAppear {
            if ProcessInfo.processInfo.hasLaunchArgumentOpenTabCalendar {
                selectedTab = .calendar
            }
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
}
