import SwiftData
import SwiftUI

/// Tap logging surface — full symptom chart. Creates a new entry or edits an
/// existing one; every save runs through the schema validation gate.
struct TapLogView: View {
    let schema: SchemaConfig
    var entry: SymptomEntry?
    /// Verbatim transcript from Talk (Phase 5) — shown at the top, never rewritten.
    var initialNote: String? = nil

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CycleService.self) private var cycleService
    @Query(sort: \SymptomEntry.timestamp, order: .reverse) private var entries: [SymptomEntry]

    @State private var values: [String: FieldValue] = [:]
    @State private var note: String = ""
    @State private var showDeleteConfirmation = false

    private var isEditing: Bool { entry != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(isEditing ? "Update what applies. Leave anything blank." : "Tap what applies. You can leave anything blank.")
                        .font(.footnote)
                        .foregroundStyle(theme.muted)

                    if !note.isEmpty {
                        noteSection
                    }

                    SchemaFormView(schema: schema, values: $values)

                    if isEditing {
                        Button("Delete entry", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                    }
                }
                .padding(20)
            }
            .background(theme.base)
            .foregroundStyle(theme.text)
            .navigationTitle(isEditing ? "Edit entry" : "Log symptoms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .confirmationDialog(
                "Delete this entry?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete entry", role: .destructive) { deleteEntry() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
            .onAppear {
                if let entry {
                    values = entry.fieldValues
                    note = entry.note ?? ""
                } else if let initialNote {
                    note = initialNote
                }
            }
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "You said")
            Text(note)
                .font(.subheadline)
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
                .accessibilityLabel("You said: \(note)")
        }
    }

    private func save() {
        let validated = schema.validated(values)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedNote = trimmedNote.isEmpty ? nil : trimmedNote

        if let entry {
            entry.fieldValues = validated
            entry.schemaVersion = schema.schemaVersion
            entry.note = storedNote
            entry.cyclePhase = cycleService.phase(for: entry.timestamp, entries: entries)
        } else {
            let timestamp = Date.now
            let extraPeriodDays = bleedingDays(from: validated, on: timestamp)
            let phase = cycleService.phase(
                for: timestamp,
                entries: entries,
                extraPeriodDays: extraPeriodDays
            )
            let newEntry = SymptomEntry(
                timestamp: timestamp,
                schemaVersion: schema.schemaVersion,
                fieldValues: validated,
                note: storedNote,
                cyclePhase: phase
            )
            modelContext.insert(newEntry)
        }

        try? modelContext.save()
        dismiss()
    }

    private func deleteEntry() {
        guard let entry else { return }
        modelContext.delete(entry)
        try? modelContext.save()
        dismiss()
    }

    private func bleedingDays(from values: [String: FieldValue], on date: Date) -> Set<Date> {
        guard case .choice(let key)? = values["bleeding"], key != "none" else {
            return []
        }
        return [Calendar.ebbCalendar.startOfDay(for: date)]
    }
}

#Preview("With transcript") {
    TapLogView(
        schema: try! SchemaConfig.load(),
        initialNote: "dull one on the right, barely there"
    )
    .modelContainer(for: SymptomEntry.self, inMemory: true)
    .environment(\.theme, .plumEmber)
    .environment(CycleService(provider: MockCycleDataProvider()))
}

#Preview("New entry") {
    TapLogView(schema: try! SchemaConfig.load())
        .modelContainer(for: SymptomEntry.self, inMemory: true)
        .environment(\.theme, .plumEmber)
        .environment(CycleService(provider: MockCycleDataProvider()))
}

#Preview("Edit entry") {
    let schema = try! SchemaConfig.load()
    let entry = SymptomEntry(
        schemaVersion: schema.schemaVersion,
        fieldValues: ["migraine_present": .boolean(true), "severity": .scale(3)]
    )
    return TapLogView(schema: schema, entry: entry)
        .modelContainer(for: SymptomEntry.self, inMemory: true)
        .environment(\.theme, .plumEmber)
        .environment(CycleService(provider: MockCycleDataProvider()))
}
