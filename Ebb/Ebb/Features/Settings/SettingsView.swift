import SwiftData
import SwiftUI

struct SettingsView: View {
    let schemaLoadResult: Result<SchemaConfig, Error>

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(CycleService.self) private var cycleService
    @Environment(AppLockController.self) private var appLock
    @Environment(CloudSyncStatusService.self) private var cloudSyncStatus
    @Query(sort: \SymptomEntry.timestamp, order: .reverse) private var entries: [SymptomEntry]

    @State private var showDebug = false
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var exportErrorMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var deleteErrorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                privacyStatusSection
                privacyControlsSection
                dataSection
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
            .sheet(isPresented: $showShareSheet, onDismiss: cleanupExportFile) {
                if let exportURL {
                    ShareSheet(items: [exportURL])
                }
            }
            .confirmationDialog(
                "Delete all symptom logs and reset cycle preferences?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes every entry from this device and your iCloud backup. It cannot be undone.")
            }
            .task {
                await cycleService.refresh()
                if AppRuntime.shouldUseCloudKitSync {
                    await cloudSyncStatus.refresh()
                }
            }
        }
    }

    // MARK: - Privacy status

    private var privacyStatusSection: some View {
        Section {
            LabeledContent {
                Text(cloudSyncStatus.statusLabel)
                    .foregroundStyle(cloudSyncStatus.isAvailable ? theme.ok : theme.muted)
            } label: {
                Label("iCloud backup", systemImage: "icloud")
            }

            LabeledContent {
                Text(appLock.lockMethodLabel)
                    .foregroundStyle(appLock.isEnabled ? theme.ok : theme.muted)
            } label: {
                Label("App lock", systemImage: "lock.fill")
            }

            Text("No account, ever. Your data stays on your devices and in your private iCloud database — Ebb never sees it.")
                .font(.footnote)
                .foregroundStyle(theme.muted)
                .listRowBackground(theme.surface)
        } header: {
            Text("Privacy")
        }
    }

    // MARK: - Privacy controls

    private var privacyControlsSection: some View {
        Section {
            Toggle(isOn: appLockToggleBinding) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lock with Face ID")
                    Text("Require Face ID, Touch ID, or your device passcode to open Ebb.")
                        .font(.caption)
                        .foregroundStyle(theme.muted)
                }
            }

            Text("iCloud backup and sync uses your Apple ID’s private CloudKit database. Sign in to iCloud in Settings to sync iPhone and iPad.")
                .font(.footnote)
                .foregroundStyle(theme.muted)
                .listRowBackground(theme.surface)
        } header: {
            Text("Backup & lock")
        }
    }

    // MARK: - Data export / delete

    private var dataSection: some View {
        Section {
            Button {
                exportData()
            } label: {
                Label("Export JSON", systemImage: "square.and.arrow.up")
            }

            if let exportErrorMessage {
                Text(exportErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(theme.pain)
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete all data", systemImage: "trash")
            }

            if let deleteErrorMessage {
                Text(deleteErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(theme.pain)
            }

            Text("Export a portable copy of your logs, or delete everything from this device and iCloud.")
                .font(.footnote)
                .foregroundStyle(theme.muted)
                .listRowBackground(theme.surface)
        } header: {
            Text("Your data")
        }
    }

    private var appLockToggleBinding: Binding<Bool> {
        Binding(
            get: { appLock.isEnabled },
            set: { newValue in
                if newValue {
                    Task { _ = await appLock.enableAfterAuthentication() }
                } else {
                    appLock.isEnabled = false
                }
            }
        )
    }

    private func exportData() {
        exportErrorMessage = nil

        guard case .success(let schema) = schemaLoadResult else {
            exportErrorMessage = "Could not load the symptom schema."
            return
        }

        do {
            exportURL = try SymptomDataExporter.makeTemporaryExportFile(
                entries: entries,
                schemaVersion: schema.schemaVersion,
                preferences: cycleService.preferences
            )
            showShareSheet = true
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func deleteAllData() {
        deleteErrorMessage = nil
        do {
            try SymptomDataExporter.deleteAllData(
                modelContext: modelContext,
                preferences: cycleService.preferences
            )
        } catch {
            deleteErrorMessage = error.localizedDescription
        }
    }

    private func cleanupExportFile() {
        if let exportURL {
            try? FileManager.default.removeItem(at: exportURL)
        }
        self.exportURL = nil
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
        .environment(AppLockController())
        .environment(CloudSyncStatusService())
        .modelContainer(for: SymptomEntry.self, inMemory: true)
}
