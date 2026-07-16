import SwiftUI

struct SettingsView: View {
    let schemaLoadResult: Result<SchemaConfig, Error>

    @Environment(\.theme) private var theme
    @Environment(CycleService.self) private var cycleService
    @State private var showDebug = false

    var body: some View {
        NavigationStack {
            List {
                healthKitSection
                cycleInfoSection

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
            .task {
                await cycleService.refresh()
            }
        }
    }

    // MARK: - HealthKit

    private var healthKitSection: some View {
        Section {
            NavigationLink {
                HealthKitSettingsView()
            } label: {
                LabeledContent {
                    Text(healthKitSummaryStatusLabel)
                        .foregroundStyle(healthKitSummaryStatusColor)
                } label: {
                    Label("HealthKit", systemImage: "heart.text.square")
                }
            }
        }
    }

    private var healthKitSummaryStatusLabel: String {
        switch cycleService.authorizationStatus {
        case .unavailable: "Unavailable"
        case .notDetermined: "Not connected"
        case .authorized:
            cycleService.healthKitPeriodDays.isEmpty ? "Connected (no data)" : "Connected"
        case .denied: "Needs permission"
        }
    }

    private var healthKitSummaryStatusColor: Color {
        switch cycleService.authorizationStatus {
        case .authorized: theme.ok
        case .denied: theme.pain
        default: theme.muted
        }
    }

    // MARK: - Cycle info

    private var cycleInfoSection: some View {
        @Bindable var preferences = cycleService.preferences

        return Section {
            Stepper(
                value: $preferences.typicalCycleLength,
                in: CyclePreferences.cycleLengthRange,
                step: 1
            ) {
                LabeledContent("Typical cycle length") {
                    Text("\(preferences.typicalCycleLength) days")
                }
            }

            Stepper(
                value: $preferences.periodLength,
                in: CyclePreferences.periodLengthRange,
                step: 1
            ) {
                LabeledContent("Typical period length") {
                    Text("\(preferences.periodLength) days")
                }
            }

            Text("Used when HealthKit has no recent flow data, and to predict your next period.")
                .font(.footnote)
                .foregroundStyle(theme.muted)
                .listRowBackground(theme.surface)

            Toggle(isOn: $preferences.hasAura) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("I get migraine aura")
                    Text("Visual or sensory warning before a migraine. Recorded for your doctor export — Ebb never gives medical advice.")
                        .font(.caption)
                        .foregroundStyle(theme.muted)
                }
            }
        } header: {
            Text("Cycle info")
        }
    }
}

#Preview {
    SettingsView(schemaLoadResult: Result { try SchemaConfig.load() })
        .environment(\.theme, .plumEmber)
        .environment(CycleService(provider: MockCycleDataProvider.lutealSample()))
}
