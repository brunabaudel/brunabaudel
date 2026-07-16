import SwiftUI

struct HealthKitSettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL
    @Environment(CycleService.self) private var cycleService
    @State private var isRequestingHealthKit = false

    var body: some View {
        List {
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
        .scrollContentBackground(.hidden)
        .background(theme.base)
        .foregroundStyle(theme.text)
        .navigationTitle("HealthKit")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await cycleService.refresh()
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
}

#Preview {
    NavigationStack {
        HealthKitSettingsView()
    }
    .environment(\.theme, .plumEmber)
    .environment(CycleService(provider: MockCycleDataProvider.lutealSample()))
}
