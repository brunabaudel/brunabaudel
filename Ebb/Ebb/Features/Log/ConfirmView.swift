import SwiftData
import SwiftUI

/// Hero confirm screen — raw transcript on top, AI-filled pills glowing,
/// everything editable, explicit save. No AI entry is saved without passing here.
struct ConfirmView: View {
    let schema: SchemaConfig
    @Bindable var viewModel: ConfirmViewModel

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CycleService.self) private var cycleService
    @Query(sort: \SymptomEntry.timestamp, order: .reverse) private var entries: [SymptomEntry]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isClassifying {
                    classifyingContent
                } else {
                    confirmContent
                }
            }
            .background(theme.base)
            .foregroundStyle(theme.text)
            .navigationTitle("Confirm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if !viewModel.isClassifying {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }
                    }
                }
            }
            .task {
                await viewModel.classifyIfNeeded()
            }
        }
    }

    private var classifyingContent: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Sorting into the chart…")
                .font(.subheadline)
                .foregroundStyle(theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sorting your words into the symptom chart")
    }

    private var confirmContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Check what I heard. Tap anything to fix it before saving.")
                    .font(.footnote)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                transcriptSection

                if viewModel.classificationFailed && viewModel.values.isEmpty {
                    emptyClassificationHint
                }

                SchemaFormView(
                    schema: schema,
                    values: $viewModel.values,
                    highlightedFields: viewModel.aiHighlights
                )
            }
            .padding(20)
        }
    }

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "You said")
            Text(TranscriptFormatting.forDisplay(viewModel.transcript))
                .font(.subheadline.monospaced())
                .foregroundStyle(theme.text)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(theme.line, lineWidth: 1)
                }
                .accessibilityLabel("You said: \(viewModel.transcript)")
        }
    }

    private var emptyClassificationHint: some View {
        Text("I couldn't map that to the chart yet — tap what applies below.")
            .font(.footnote)
            .foregroundStyle(theme.muted)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(theme.line, lineWidth: 1)
            }
    }

    private func save() {
        let validated = schema.validated(viewModel.values)
        let trimmedNote = viewModel.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedNote = trimmedNote.isEmpty ? nil : trimmedNote
        let timestamp = Date.now
        let extraPeriodDays = bleedingDays(from: validated, on: timestamp)
        let phase = cycleService.phase(
            for: timestamp,
            entries: entries,
            extraPeriodDays: extraPeriodDays
        )

        let entry = SymptomEntry(
            timestamp: timestamp,
            schemaVersion: schema.schemaVersion,
            fieldValues: validated,
            note: storedNote,
            cyclePhase: phase
        )
        modelContext.insert(entry)
        try? modelContext.save()
        LocalEntrySaveNotifier.notifySaved()
        dismiss()
    }

    private func bleedingDays(from values: [String: FieldValue], on date: Date) -> Set<Date> {
        guard case .choice(let key)? = values["bleeding"], key != "none" else {
            return []
        }
        return [Calendar.ebbCalendar.startOfDay(for: date)]
    }
}

#Preview("Classifying") {
    ConfirmView(
        schema: try! SchemaConfig.load(),
        viewModel: ConfirmViewModel(
            transcript: "dull one on the right, barely there",
            schema: try! SchemaConfig.load(),
            classifier: MockSymptomClassifier(fixedValues: [:])
        )
    )
    .modelContainer(for: SymptomEntry.self, inMemory: true)
    .environment(\.theme, .plumEmber)
    .environment(CycleService(provider: MockCycleDataProvider()))
}

#Preview("Filled") {
    let schema = try! SchemaConfig.load()
    let classifier = MockSymptomClassifier(fixedValues: [
        "migraine_present": .boolean(true),
        "severity": .scale(1),
        "location": .choices(["right"]),
        "quality": .choices(["dull"]),
        "worse_with_movement": .boolean(true),
    ])
    let viewModel = ConfirmViewModel(
        transcript: "dull one on the right, barely there, worse when I move",
        schema: schema,
        classifier: classifier
    )
    return ConfirmView(schema: schema, viewModel: viewModel)
        .modelContainer(for: SymptomEntry.self, inMemory: true)
        .environment(\.theme, .plumEmber)
        .environment(CycleService(provider: MockCycleDataProvider()))
        .task { await viewModel.classifyIfNeeded() }
}
