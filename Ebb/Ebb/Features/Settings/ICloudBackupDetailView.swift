import CloudKit
import Foundation
import SwiftUI
import UIKit

/// Explains where Ebb stores iCloud backups and surfaces backup progress + retry.
struct ICloudBackupDetailView: View {
    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Environment(CloudSyncStatusService.self) private var cloudSyncStatus

    var body: some View {
        List {
            statusSection
            destinationSection
            if showBackupProgress {
                progressSection
            }
            actionsSection
        }
        .scrollContentBackground(.hidden)
        .background(theme.base)
        .foregroundStyle(theme.text)
        .navigationTitle("iCloud backup")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await cloudSyncStatus.refresh()
        }
    }

    private var showBackupProgress: Bool {
        cloudSyncStatus.isBackupInProgress
            || cloudSyncStatus.backupPhase == .stalled
            || cloudSyncStatus.statusLabel == "Backing up to iCloud…"
    }

    private var statusSection: some View {
        Section {
            LabeledContent {
                Text(cloudSyncStatus.statusLabel)
                    .foregroundStyle(statusColor)
            } label: {
                Label("Status", systemImage: "icloud")
            }

            LabeledContent {
                Text(cloudSyncStatus.iCloudAccountSummary)
                    .foregroundStyle(theme.muted)
            } label: {
                Label("Apple ID", systemImage: "person.crop.circle")
            }

            if let lastBackupError = cloudSyncStatus.lastBackupError {
                Text(lastBackupError)
                    .font(.footnote)
                    .foregroundStyle(theme.pain)
                    .listRowBackground(theme.surface)
            }
        } header: {
            Text("Current status")
        }
    }

    private var destinationSection: some View {
        Section {
            LabeledContent {
                Text("Private iCloud database")
                    .foregroundStyle(theme.muted)
            } label: {
                Label("Storage type", systemImage: "lock.icloud")
            }

            LabeledContent {
                Text(CloudSyncStatusService.containerIdentifier)
                    .font(.caption.monospaced())
                    .foregroundStyle(theme.muted)
                    .multilineTextAlignment(.trailing)
            } label: {
                Label("Container", systemImage: "externaldrive")
            }

            Text(
                "Your logs live in Ebb’s private iCloud area tied to your Apple ID. "
                + "They are not visible in Files or iCloud Drive — only Ebb can read them on devices signed into the same Apple ID."
            )
            .font(.footnote)
            .foregroundStyle(theme.muted)
            .listRowBackground(theme.surface)
        } header: {
            Text("Where backups go")
        }
    }

    private var progressSection: Section<Text, CloudBackupProgressView, EmptyView> {
        Section {
            CloudBackupProgressView(
                phaseLabel: cloudSyncStatus.backupPhaseLabel,
                progress: cloudSyncStatus.backupProgress,
                verificationStep: cloudSyncStatus.verificationStep,
                verificationStepCount: cloudSyncStatus.verificationStepCount,
                isIndeterminate: cloudSyncStatus.backupPhase == .uploading
                    && !cloudSyncStatus.isExportInProgress
            )
            .listRowBackground(theme.surface)
        } header: {
            Text("Backup progress")
        }
    }

    private var actionsSection: some View {
        Section {
            Button("Open iPhone Settings") {
                openSettingsApp()
            }

            if cloudSyncStatus.isCloudKitSyncActive,
               cloudSyncStatus.trackedEntryCount > 0,
               !cloudSyncStatus.hasConfirmedBackup {
                Button("Retry backup") {
                    retryBackup()
                }
            }

            Text(
                "In Settings, tap your name at the top, then iCloud, and make sure you are signed in and iCloud is enabled. "
                + "Stay on Wi‑Fi until backup progress reaches 100% before deleting the app."
            )
            .font(.footnote)
            .foregroundStyle(theme.muted)
            .listRowBackground(theme.surface)
        } header: {
            Text("Actions")
        }
    }

    private var statusColor: Color {
        if cloudSyncStatus.hasConfirmedBackup {
            theme.ok
        } else if cloudSyncStatus.backupPhase == .stalled || cloudSyncStatus.lastBackupError != nil {
            theme.pain
        } else {
            theme.muted
        }
    }

    private func openSettingsApp() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private func retryBackup() {
        try? modelContext.save()
        cloudSyncStatus.retryBackupAttempt()
    }
}

#Preview {
    NavigationStack {
        ICloudBackupDetailView()
    }
    .environment(\.theme, .plumEmber)
    .environment(CloudSyncStatusService(storageMode: .cloudKit))
    .modelContainer(for: SymptomEntry.self, inMemory: true)
}
