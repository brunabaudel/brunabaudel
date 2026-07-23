import SwiftData
import SwiftUI

/// Doctor-ready PDF preview and export (build-plan Phase 11).
struct DoctorExportView: View {
    let schema: SchemaConfig

    @Environment(\.theme) private var theme
    @Environment(CycleService.self) private var cycleService
    @Environment(EntitlementsService.self) private var entitlements
    @Query(sort: \SymptomEntry.timestamp, order: .reverse) private var entries: [SymptomEntry]

    @State private var showPaywall = false
    @State private var exportFile: ShareableFile?
    @State private var exportErrorMessage: String?
    @State private var isExportingPDF = false
    @State private var exportTask: Task<Void, Never>?

    private var overlay: CalendarCycleOverlay {
        cycleService.makeOverlay(from: entries)
    }

    private var report: DoctorReportEngine.Report {
        DoctorReportEngine.buildReport(
            entries: entries,
            schema: schema,
            overlay: overlay,
            hasAuraPreference: cycleService.preferences.hasAura,
            typicalCycleLength: cycleService.preferences.typicalCycleLength
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("A clean summary of your pattern, generated on your phone. Nothing is uploaded.")
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                if report.hasEnoughData {
                    reportCard
                        .padding(.top, 18)
                } else {
                    emptyCard
                        .padding(.top, 18)
                }

                exportButton
                    .padding(.top, 24)

                if let exportErrorMessage {
                    Text(exportErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(theme.pain)
                        .padding(.top, 10)
                }

                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(theme.muted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 11)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(theme.base)
        .foregroundStyle(theme.text)
        .navigationTitle("Bring to your doctor")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $exportFile, onDismiss: cleanupExportFile) { file in
            ShareSheet(items: [file.url])
        }
        .sheet(isPresented: $showPaywall) {
            EbbPlusPaywallSheet()
        }
        .onDisappear {
            exportTask?.cancel()
            exportTask = nil
            isExportingPDF = false
        }
    }

    // MARK: - Report card

    private var reportCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Migraine summary")
                    .font(.system(.headline, design: .serif))
                Spacer(minLength: 8)
                Text(report.dateRangeLabel)
                    .font(.caption.monospaced())
                    .foregroundStyle(theme.muted)
            }

            Text(attributedSummary(report.summaryLine))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            statsRow

            VStack(alignment: .leading, spacing: 8) {
                metaLine(title: "Triggers", value: DoctorReportEngine.triggersLine(from: report.topTriggers))
                metaLine(title: "Relief tried", value: DoctorReportEngine.reliefLine(from: report.reliefSummaries))
                metaLine(title: "Aura", value: report.auraSummary)
                metaLine(title: "Cycle", value: report.cycleSummary)
            }
            .font(.footnote)
        }
        .padding(18)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(theme.line, lineWidth: 1)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statColumn(
                value: DoctorReportEngine.formattedAverage(report.avgMigrainesPerCycle),
                label: "AVG / CYCLE"
            )
            statColumn(
                value: DoctorReportEngine.formattedAverage(report.avgSeverity),
                label: "AVG SEVERITY"
            )
            statColumn(
                value: report.lutealPercentage.map { "\($0)%" } ?? "—",
                label: "IN LUTEAL",
                accent: true
            )
        }
    }

    private func statColumn(value: String, label: String, accent: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(accent ? theme.cycle : theme.text)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.muted)
                .kerning(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    private func metaLine(title: String, value: String) -> some View {
        Text(attributedMeta(title: title, value: value))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var emptyCard: some View {
        ContentUnavailableView {
            Label("No migraines yet", systemImage: "doc.text")
        } description: {
            Text("Log a migraine to build a summary you can share with your GP or neurologist.")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(theme.line, lineWidth: 1)
        }
    }

    // MARK: - Export

    private var exportButton: some View {
        Button(action: exportPDF) {
            Group {
                if isExportingPDF {
                    ProgressView()
                        .tint(theme.onPain)
                } else {
                    Label("Export PDF", systemImage: "square.and.arrow.up")
                        .font(.body.weight(.bold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.onPain)
        .background(theme.pain, in: RoundedRectangle(cornerRadius: 16))
        .disabled(!report.hasEnoughData || isExportingPDF)
        .opacity(report.hasEnoughData ? 1 : 0.45)
    }

    private var footnote: String {
        if report.hasEnoughData {
            return "Generated on-device · \(report.cycleCount) cycles · \(report.migraineCount) migraines"
        }
        return "Generated on-device · nothing leaves your phone"
    }

    private func exportPDF() {
        exportErrorMessage = nil

        guard report.hasEnoughData, !isExportingPDF else { return }

        guard entitlements.isEbbPlus else {
            showPaywall = true
            return
        }

        let reportSnapshot = report
        exportTask?.cancel()
        isExportingPDF = true

        exportTask = Task { @MainActor in
            do {
                let url = try await Task.detached(priority: .userInitiated) {
                    try DoctorReportPDFRenderer.makeTemporaryPDFFile(report: reportSnapshot)
                }.value

                guard !Task.isCancelled else {
                    try? FileManager.default.removeItem(at: url)
                    isExportingPDF = false
                    return
                }

                isExportingPDF = false
                await Task.yield()
                guard !Task.isCancelled else {
                    try? FileManager.default.removeItem(at: url)
                    return
                }
                exportFile = ShareableFile(url: url)
            } catch is CancellationError {
                isExportingPDF = false
            } catch {
                isExportingPDF = false
                exportErrorMessage = error.localizedDescription
            }
        }
    }

    private func cleanupExportFile() {
        if let url = exportFile?.url {
            try? FileManager.default.removeItem(at: url)
        }
        exportFile = nil
    }

    // MARK: - Attributed text

    private func attributedSummary(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        if let range = result.range(of: "luteal phase", options: .caseInsensitive) {
            result[range].foregroundColor = theme.cycle
            result[range].font = .subheadline.weight(.semibold)
        }
        return result
    }

    private func attributedMeta(title: String, value: String) -> AttributedString {
        var result = AttributedString("\(title) · \(value)")
        if let range = result.range(of: title) {
            result[range].font = .footnote.weight(.semibold)
        }
        if let range = result.range(of: " · \(value)") {
            result[range].foregroundColor = theme.muted
        }
        return result
    }
}

#Preview("With data") {
    let schema = try! SchemaConfig.load()
    let container = try! ModelContainer(
        for: SymptomEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let cal = Calendar.ebbCalendar
    let periodStart = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!

    container.mainContext.insert(SymptomEntry(
        timestamp: periodStart,
        schemaVersion: schema.schemaVersion,
        fieldValues: ["bleeding": .choice("medium")]
    ))
    for day in [17, 20, 25] {
        let date = cal.date(byAdding: .day, value: day - 1, to: periodStart)!
        container.mainContext.insert(SymptomEntry(
            timestamp: cal.date(bySettingHour: 20, minute: 0, second: 0, of: date)!,
            schemaVersion: schema.schemaVersion,
            fieldValues: [
                "migraine_present": .boolean(true),
                "severity": .scale(4),
                "location": .choices(["right"]),
                "triggers": .choices(["poor_sleep", "stress"]),
                "relief_taken": .choices(["ibuprofen"]),
                "relief_effect": .choice("partial"),
            ],
            cyclePhase: .luteal
        ))
    }

    return NavigationStack {
        DoctorExportView(schema: schema)
    }
    .modelContainer(container)
    .environment(\.theme, .plumEmber)
    .environment(CycleService(provider: MockCycleDataProvider()))
    .environment(EntitlementsService(previewIsEbbPlus: true, listenForUpdates: false))
}

#Preview("Empty") {
    NavigationStack {
        DoctorExportView(schema: try! SchemaConfig.load())
    }
    .modelContainer(for: SymptomEntry.self, inMemory: true)
    .environment(\.theme, .plumEmber)
    .environment(CycleService(provider: MockCycleDataProvider()))
    .environment(EntitlementsService(previewIsEbbPlus: false, listenForUpdates: false))
}
