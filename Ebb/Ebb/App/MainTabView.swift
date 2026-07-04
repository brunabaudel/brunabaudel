import SwiftUI

/// Root tab scaffold: Today · Calendar · Patterns · Settings.
struct MainTabView: View {
    let schema: SchemaConfig
    let schemaLoadResult: Result<SchemaConfig, Error>

    @Environment(\.theme) private var theme
    @State private var selectedTab = Tab.today

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(schema: schema)
                .tag(Tab.today)
                .tabItem {
                    Label("Today", systemImage: "sun.max")
                }

            CalendarView()
                .tag(Tab.calendar)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            PatternsView()
                .tag(Tab.patterns)
                .tabItem {
                    Label("Patterns", systemImage: "chart.line.uptrend.xyaxis")
                }

            SettingsView(schemaLoadResult: schemaLoadResult)
                .tag(Tab.settings)
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

private enum Tab {
    static let today = 0
    static let calendar = 1
    static let patterns = 2
    static let settings = 3
}

#Preview {
    MainTabView(
        schema: try! SchemaConfig.load(),
        schemaLoadResult: Result { try SchemaConfig.load() }
    )
    .environment(\.theme, .plumEmber)
}
