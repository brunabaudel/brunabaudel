import SwiftData
import SwiftUI

struct TodayView: View {
    let schema: SchemaConfig

    @Environment(\.theme) private var theme
    @Query(sort: \SymptomEntry.timestamp, order: .reverse) private var entries: [SymptomEntry]

    @State private var showTapLog = false
    @State private var editingEntry: SymptomEntry?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    CyclePhaseRing(
                        phase: .luteal,
                        cycleDay: 22,
                        cycleLength: 28,
                        summary: "Placeholder until HealthKit connects in Phase 4."
                    )
                    daySummarySection
                    logButtons
                    entriesSection
                }
                .padding(20)
            }
            .background(theme.base)
            .foregroundStyle(theme.text)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showTapLog) {
                TapLogView(schema: schema)
            }
            .sheet(item: $editingEntry) { entry in
                TapLogView(schema: schema, entry: entry)
            }
            .onAppear {
                if ProcessInfo.processInfo.hasLaunchArgumentAutoTapLog {
                    showTapLog = true
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today")
                .font(.system(.title, design: .serif))
            Text(Date.now.formatted(date: .complete, time: .omitted))
                .font(.footnote)
                .foregroundStyle(theme.muted)
        }
    }

    private var daySummarySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Your day")
            Text(DaySummaryBuilder.todaySummary(entries: entries, schema: schema))
                .font(.subheadline)
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var logButtons: some View {
        HStack(spacing: 11) {
            Button {} label: {
                logButton(
                    title: "Talk",
                    hint: "Coming in Phase 5",
                    style: .talk,
                    systemImage: "mic.fill"
                )
            }
            .disabled(true)

            Button { showTapLog = true } label: {
                logButton(
                    title: "Tap",
                    hint: "Log with buttons",
                    style: .tap,
                    systemImage: "hand.tap.fill"
                )
            }
        }
    }

    @ViewBuilder
    private var entriesSection: some View {
        if entries.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Recent")
                ForEach(recentEntries) { entry in
                    Button { editingEntry = entry } label: {
                        EntryCard(entry: entry, schema: schema)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Your log")
            Text("Your log starts here. Tap above to record how you're feeling — no account, everything stays on this device.")
                .font(.subheadline)
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(theme.line, lineWidth: 1)
        }
    }

    private var recentEntries: [SymptomEntry] {
        Array(entries.prefix(10))
    }

    private enum LogButtonStyle { case talk, tap }

    private func logButton(
        title: String,
        hint: String,
        style: LogButtonStyle,
        systemImage: String
    ) -> some View {
        VStack(spacing: 3) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
            Text(hint)
                .font(.caption2)
                .opacity(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .foregroundStyle(style == .talk ? theme.onPain : theme.text)
        .background {
            if style == .talk {
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.pain)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(theme.line, lineWidth: 1)
            }
        }
    }
}

#Preview("Empty") {
    TodayView(schema: try! SchemaConfig.load())
        .modelContainer(for: SymptomEntry.self, inMemory: true)
        .environment(\.theme, .plumEmber)
}

#Preview("With entries") {
    let schema = try! SchemaConfig.load()
    let container = try! ModelContainer(for: SymptomEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let entry = SymptomEntry(
        schemaVersion: schema.schemaVersion,
        fieldValues: [
            "migraine_present": .boolean(true),
            "severity": .scale(3),
            "location": .choices(["right"]),
        ]
    )
    container.mainContext.insert(entry)
    return TodayView(schema: schema)
        .modelContainer(container)
        .environment(\.theme, .plumEmber)
}
