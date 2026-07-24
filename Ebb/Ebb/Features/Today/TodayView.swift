import SwiftData
import SwiftUI

struct TodayView: View {
    let schema: SchemaConfig

    @Environment(\.theme) private var theme
    @Environment(CycleService.self) private var cycleService
    @Query(sort: \SymptomEntry.timestamp, order: .reverse) private var entries: [SymptomEntry]

    @State private var showTapLog = false
    @State private var showTalkLog = false
    @State private var showConfirm = false
    @State private var confirmViewModel: ConfirmViewModel?
    @State private var editingEntry: SymptomEntry?

    @Environment(\.symptomClassifier) private var symptomClassifier
    @Environment(MedicationPreferences.self) private var medicationPreferences

    private var cycleSnapshot: CycleSnapshot {
        cycleService.snapshot(for: .now, entries: entries)
    }

    private var todaysEntries: [SymptomEntry] {
        let calendar = Calendar.current
        return entries
            .filter { calendar.isDate($0.timestamp, inSameDayAs: .now) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    cycleRing
                    TodayIntensityStrip(entries: todaysEntries)
                }
                .padding(20)

                ScrollView {
                    entriesSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 96)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .background(theme.base)
            .foregroundStyle(theme.text)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottom) {
                talkFAB
                    .padding(.bottom, 22)
            }
            .sheet(isPresented: $showTapLog) {
                TapLogView(schema: schema)
            }
            .sheet(isPresented: $showTalkLog) {
                TalkView(schema: schema) { transcript in
                    confirmViewModel = ConfirmViewModel(
                        transcript: transcript,
                        schema: schema,
                        classifier: symptomClassifier,
                        medicationPreferences: medicationPreferences
                    )
                    showConfirm = true
                }
            }
            .sheet(isPresented: $showConfirm, onDismiss: {
                confirmViewModel = nil
            }) {
                if let confirmViewModel {
                    ConfirmView(schema: schema, viewModel: confirmViewModel)
                }
            }
            .sheet(item: $editingEntry) { entry in
                TapLogView(schema: schema, entry: entry)
            }
            .onAppear {
                if ProcessInfo.processInfo.hasLaunchArgumentAutoTapLog {
                    showTapLog = true
                }
                if ProcessInfo.processInfo.hasLaunchArgumentAutoTalkLog {
                    showTalkLog = true
                }
                if ProcessInfo.processInfo.hasLaunchArgumentAutoConfirmLog,
                   let transcript = ProcessInfo.processInfo.mockTranscriptText {
                    confirmViewModel = ConfirmViewModel(
                        transcript: transcript,
                        schema: schema,
                        classifier: symptomClassifier,
                        medicationPreferences: medicationPreferences
                    )
                    showConfirm = true
                }
            }
        }
    }

    @ViewBuilder
    private var cycleRing: some View {
        if let phase = cycleSnapshot.phase, let cycleDay = cycleSnapshot.cycleDay {
            CyclePhaseRing(
                phase: phase,
                cycleDay: cycleDay,
                cycleLength: cycleSnapshot.cycleLength,
                summary: cycleSnapshot.summary
            )
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cycle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.cycle)
                Text(cycleSnapshot.summary)
                    .font(.caption)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(theme.line, lineWidth: 1)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.system(.title, design: .serif))
                Text(Date.now.formatted(date: .complete, time: .omitted))
                    .font(.footnote)
                    .foregroundStyle(theme.muted)
            }
            Spacer(minLength: 12)
            Button { showTapLog = true } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.light))
                    .foregroundStyle(theme.text)
                    .frame(width: 34, height: 34)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(theme.line, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log symptoms")
        }
    }

    @ViewBuilder
    private var entriesSection: some View {
        if todaysEntries.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                ForEach(todaysEntries) { entry in
                    Button { editingEntry = entry } label: {
                        TodayEntryRow(entry: entry, schema: schema)
                    }
                    .buttonStyle(.plain)

                    if entry.id != todaysEntries.last?.id {
                        Divider().overlay(theme.line)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        Text("Nothing logged yet today. Tap + or use the mic button below.")
            .font(.subheadline)
            .foregroundStyle(theme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Nothing logged yet today. Tap plus or use the mic button below.")
    }

    private var talkFAB: some View {
        Button { showTalkLog = true } label: {
            Image(systemName: "mic.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(theme.onPain)
                .frame(width: 64, height: 64)
                .background(theme.pain, in: Circle())
                .shadow(color: theme.pain.opacity(0.5), radius: 14, y: 4)
        }
        .accessibilityLabel("Talk")
        .accessibilityHint("Say how you feel")
    }
}

#Preview("Empty") {
    TodayView(schema: try! SchemaConfig.load())
        .modelContainer(for: SymptomEntry.self, inMemory: true)
        .environment(\.theme, .plumEmber)
        .environment(CycleService(provider: MockCycleDataProvider.lutealSample()))
        .environment(SpeechCapture(provider: MockSpeechRecognizer(transcript: "")))
        .environment(MedicationPreferences())
        .environment(\.symptomClassifier, SynonymSymptomClassifier())
}

#Preview("With entries") {
    let schema = try! SchemaConfig.load()
    let container = try! ModelContainer(for: SymptomEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let calendar = Calendar.current
    let migraine = SymptomEntry(
        timestamp: calendar.date(bySettingHour: 21, minute: 8, second: 0, of: .now)!,
        schemaVersion: schema.schemaVersion,
        fieldValues: [
            "migraine_present": .boolean(true),
            "severity": .scale(4),
            "location": .choices(["right"]),
            "associated_symptoms": .choices(["nausea"]),
            "relief_taken": .choices(["ibuprofen"]),
        ]
    )
    let spotting = SymptomEntry(
        timestamp: calendar.date(bySettingHour: 14, minute: 15, second: 0, of: .now)!,
        schemaVersion: schema.schemaVersion,
        fieldValues: [
            "migraine_present": .boolean(false),
            "bleeding": .choice("spotting"),
            "cramps_severity": .scale(2),
        ],
        cyclePhase: .luteal
    )
    container.mainContext.insert(migraine)
    container.mainContext.insert(spotting)
    return TodayView(schema: schema)
        .modelContainer(container)
        .environment(\.theme, .plumEmber)
        .environment(CycleService(provider: MockCycleDataProvider.lutealSample()))
        .environment(SpeechCapture(provider: MockSpeechRecognizer(transcript: "")))
        .environment(MedicationPreferences())
        .environment(\.symptomClassifier, SynonymSymptomClassifier())
}
