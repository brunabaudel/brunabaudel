import SwiftUI

struct SettingsView: View {
    let schemaLoadResult: Result<SchemaConfig, Error>

    @Environment(\.theme) private var theme
    @State private var showDebug = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("HealthKit", systemImage: "heart.text.square")
                    Label("Appearance", systemImage: "paintpalette")
                    Label("Reminders", systemImage: "bell")
                } header: {
                    Text("Preferences")
                }

                #if DEBUG
                Section {
                    Button("Phase 0 debug screen") {
                        showDebug = true
                    }
                } header: {
                    Text("Developer")
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            .background(theme.base)
            .foregroundStyle(theme.text)
            .navigationTitle("Settings")
            .sheet(isPresented: $showDebug) {
                NavigationStack {
                    DebugScreen(schemaLoadResult: schemaLoadResult)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showDebug = false }
                            }
                        }
                }
            }
        }
    }
}

#Preview {
    SettingsView(schemaLoadResult: Result { try SchemaConfig.load() })
        .environment(\.theme, .plumEmber)
}
