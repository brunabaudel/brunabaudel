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
    @State private var syncPreferences = SyncPreferences()
    @State private var showSyncRestartAlert = false
    @State private var pendingSyncPreferenceValue = true

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
                Text(deleteAllDataMessage)
            }
            .alert("Restart required", isPresented: $showSyncRestartAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(syncRestartMessage)
            }
            .task {
                await cycleService.refresh()
                await cloudSyncStatus.refresh()
            }
        }
    }

    // MARK: - Privacy status

    private var privacyStatusSection: some View {
        Section {
            LabeledContent {
                Text(cloudSyncStatus.statusLabel)
                    .foregroundStyle(cloudSyncStatus.isCloudKitSyncActive ? theme.ok : theme.muted)
            } label: {
                Label("iCloud backup", systemImage: "icloud")
            }

            if cloudSyncStatus.restorePhase == .noBackupFound {
                Text("No backup found for this Apple ID. Logs upload while Ebb is open — wait a minute after saving before deleting the app. Data logged before iCloud was enabled may not be in the cloud.")
                    .font(.footnote)
                    .foregroundStyle(theme.muted)
                    .listRowBackground(theme.surface)
            }

            LabeledContent {
                Text(appLock.lockMethodLabel)
                    .foregroundStyle(appLock.isEnabled ? theme.ok : theme.muted)
            } label: {
                Label("App lock", systemImage: "lock.fill")
            }

            Text(privacyExplanation)
                .font(.footnote)
                .foregroundStyle(theme.muted)
                .listRowBackground(theme.surface)
        } header: {
            Text("Privacy")
        }
    }

    private var privacyExplanation: String {
        if cloudSyncStatus.isCloudKitSyncActive {
            return "No account, ever. Your logs sync to your private iCloud database — Ebb never sees them."
        }
        return "No account, ever. Your logs stay on this device only — Ebb never sees them."
    }

    // MARK: - Privacy controls

    private var privacyControlsSection: some View {
        Section {
            Toggle(isOn: iCloudSyncToggleBinding) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("iCloud backup & sync")
                    Text("Back up logs and sync iPhone and iPad via your Apple ID. Turn off to keep data on this device only.")
                        .font(.caption)
                        .foregroundStyle(theme.muted)
                }
            }

            if syncPreferenceMismatch {
                Text("Quit and reopen Ebb to apply this change.")
                    .font(.footnote)
                    .foregroundStyle(theme.pain)
                    .listRowBackground(theme.surface)
            }

            Toggle(isOn: appLockToggleBinding) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lock with Face ID")
                    Text("Require Face ID, Touch ID, or your device passcode to open Ebb.")
                        .font(.caption)
                        .foregroundStyle(theme.muted)
                }
            }
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

            Text(exportDeleteFootnote)
                .font(.footnote)
                .foregroundStyle(theme.muted)
                .listRowBackground(theme.surface)
        } header: {
            Text("Your data")
        }
    }

    private var deleteAllDataMessage: String {
        if cloudSyncStatus.isCloudKitSyncActive {
            return "This removes every entry from this device and your iCloud backup. It cannot be undone."
        }
        return "This removes every entry from this device. It cannot be undone."
    }

    private var exportDeleteFootnote: String {
        if cloudSyncStatus.isCloudKitSyncActive {
            return "Export a portable copy of your logs, or delete everything from this device and iCloud."
        }
        return "Export a portable copy of your logs, or delete everything stored on this device."
    }

    private var syncPreferenceMismatch: Bool {
        switch cloudSyncStatus.storageMode {
        case .cloudKit:
            return !syncPreferences.iCloudSyncEnabled
        case .localByChoice:
            return syncPreferences.iCloudSyncEnabled
        default:
            return false
        }
    }

    private var syncRestartMessage: String {
        if pendingSyncPreferenceValue {
            return "Ebb will sync via iCloud the next time you open it. Your existing iCloud backup is still there if you had one."
        }
        return "New logs will stay on this device only the next time you open Ebb. Any existing iCloud backup stays in your Apple ID until you turn sync back on."
    }

    private var iCloudSyncToggleBinding: Binding<Bool> {
        Binding(
            get: { syncPreferences.iCloudSyncEnabled },
            set: { newValue in
                guard newValue != syncPreferences.iCloudSyncEnabled else { return }
                pendingSyncPreferenceValue = newValue
                syncPreferences.iCloudSyncEnabled = newValue
                showSyncRestartAlert = true
            }
        )
    }

    private var appLockToggleBinding: Binding<Bool> {
        Binding(
            get: { appLock.isEnabled },
            set: { newValue in
                if newValue {
                    Task {
                        // Wait for the toggle animation to finish before Face ID.
                        try? await Task.sleep(for: .milliseconds(400))
                        await appLock.enableAfterAuthentication()
                    }
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
        .environment(CloudSyncStatusService(storageMode: .localByChoice))
        .modelContainer(for: SymptomEntry.self, inMemory: true)
}
