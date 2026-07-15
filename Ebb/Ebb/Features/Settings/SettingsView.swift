import SwiftUI

struct SettingsView: View {
    let schemaLoadResult: Result<SchemaConfig, Error>

    @Environment(\.theme) private var theme
    @Environment(CycleService.self) private var cycleService
    @State private var showDebug = false
    @State private var isRequestingHealthKit = false

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
        }
    }

    // MARK: - HealthKit

    private var healthKitSection: some View {
        Section {
            LabeledContent {
                Text(healthKitStatusLabel)
                    .foregroundStyle(healthKitStatusColor)
            } label: {
                Label("Connection", systemImage: "heart.text.square")
            }

            Text("Ebb reads menstrual flow from HealthKit to tag your cycle phase and predict your next period. Nothing is written back to HealthKit.")
                .font(.footnote)
                .foregroundStyle(theme.muted)
                .listRowBackground(theme.surface)

            if cycleService.authorizationStatus == .notDetermined {
                Button {
                    Task { await connectHealthKit() }
                } label: {
                    if isRequestingHealthKit {
                        ProgressView()
                    } else {
                        Text("Connect HealthKit")
                    }
                }
                .disabled(isRequestingHealthKit)
            } else if cycleService.authorizationStatus == .denied {
                Text("Open the Health app → Sharing → Apps → Ebb to allow menstrual data.")
                    .font(.footnote)
                    .foregroundStyle(theme.muted)
            } else if cycleService.authorizationStatus == .authorized {
                Button("Refresh cycle data") {
                    Task { await cycleService.refresh() }
                }
            }
        } header: {
            Text("HealthKit")
        }
    }

    private var healthKitStatusLabel: String {
        switch cycleService.authorizationStatus {
        case .unavailable: "Unavailable"
        case .notDetermined: "Not connected"
        case .authorized: "Connected"
        case .denied: "Access denied"
        }
    }

    private var healthKitStatusColor: Color {
        switch cycleService.authorizationStatus {
        case .authorized: theme.ok
        case .denied: theme.pain
        default: theme.muted
        }
    }

    private func connectHealthKit() async {
        isRequestingHealthKit = true
        defer { isRequestingHealthKit = false }
        await cycleService.requestAuthorization()
    }

    // MARK: - Cycle info

    private var cycleInfoSection: some View {
        Section {
            Stepper(
                value: Bindable(cycleService.preferences).typicalCycleLength,
                in: CyclePreferences.cycleLengthRange,
                step: 1
            ) {
                LabeledContent("Typical cycle length") {
                    Text("\(cycleService.preferences.typicalCycleLength) days")
                }
            }

            Stepper(
                value: Bindable(cycleService.preferences).periodLength,
                in: CyclePreferences.periodLengthRange,
                step: 1
            ) {
                LabeledContent("Typical period length") {
                    Text("\(cycleService.preferences.periodLength) days")
                }
            }

            Text("Used when HealthKit has no recent flow data, and to predict your next period.")
                .font(.footnote)
                .foregroundStyle(theme.muted)
                .listRowBackground(theme.surface)

            Toggle(isOn: Bindable(cycleService.preferences).hasAura) {
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
