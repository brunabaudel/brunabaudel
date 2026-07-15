import SwiftUI

struct SettingsView: View {
    let schemaLoadResult: Result<SchemaConfig, Error>

    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL
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
            .task {
                await cycleService.refresh()
            }
        }
    }

    // MARK: - HealthKit

    private var healthKitSection: some View {
        Section {
            healthKitConnectionRow

            Text(healthKitExplanation)
                .font(.footnote)
                .foregroundStyle(theme.muted)
                .listRowBackground(theme.surface)

            healthKitActions
        } header: {
            Text("HealthKit")
        }
    }

    @ViewBuilder
    private var healthKitConnectionRow: some View {
        switch cycleService.authorizationStatus {
        case .authorized, .unavailable:
            healthKitConnectionLabel

        case .notDetermined, .denied:
            Button {
                Task { await connectHealthKit() }
            } label: {
                healthKitConnectionLabel
            }
            .disabled(isRequestingHealthKit)
        }
    }

    private var healthKitConnectionLabel: some View {
        LabeledContent {
            Text(healthKitStatusLabel)
                .foregroundStyle(healthKitStatusColor)
        } label: {
            Label("Connection", systemImage: "heart.text.square")
        }
    }

    @ViewBuilder
    private var healthKitActions: some View {
        switch cycleService.authorizationStatus {
        case .notDetermined:
            if isRequestingHealthKit {
                ProgressView()
            }

        case .authorized:
            Button("Refresh cycle data") {
                Task { await cycleService.refresh() }
            }
            if cycleService.healthKitPeriodDays.isEmpty {
                Text("No menstrual flow data found yet. In the Health app, open Sharing → Apps → Ebb and turn on Menstrual Cycle.")
                    .font(.footnote)
                    .foregroundStyle(theme.muted)
            }
            Button("Open Health app") {
                openURL(URL(string: "x-apple-health://")!)
            }

        case .denied:
            Text("Ebb cannot read menstrual data. Open the Health app → Sharing → Apps → Ebb and allow Menstrual Cycle.")
                .font(.footnote)
                .foregroundStyle(theme.muted)
            Button("Open Health app") {
                openURL(URL(string: "x-apple-health://")!)
            }

        case .unavailable:
            Text("HealthKit is not available on this device.")
                .font(.footnote)
                .foregroundStyle(theme.muted)
        }
    }

    private var healthKitExplanation: String {
        "Ebb reads menstrual flow from HealthKit to tag your cycle phase and predict your next period. Nothing is written to HealthKit."
    }

    private var healthKitStatusLabel: String {
        switch cycleService.authorizationStatus {
        case .unavailable: "Unavailable"
        case .notDetermined: "Not connected — tap to connect"
        case .authorized:
            cycleService.healthKitPeriodDays.isEmpty ? "Connected (no data yet)" : "Connected"
        case .denied: "Needs permission — tap to try again"
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
