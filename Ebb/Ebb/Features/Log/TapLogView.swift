import SwiftData
import SwiftUI

/// Tap logging surface — full symptom chart. Creates a new entry or edits an
/// existing one; every save runs through the schema validation gate.
struct TapLogView: View {
    let schema: SchemaConfig
    var entry: SymptomEntry?

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var values: [String: FieldValue] = [:]
    @State private var showDeleteConfirmation = false

    private var isEditing: Bool { entry != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(isEditing ? "Update what applies. Leave anything blank." : "Tap what applies. You can leave anything blank.")
                        .font(.footnote)
                        .foregroundStyle(theme.muted)

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
                }
            }
        }
    }

    private func save() {
        let validated = schema.validated(values)

        if let entry {
            entry.fieldValues = validated
            entry.schemaVersion = schema.schemaVersion
        } else {
            let newEntry = SymptomEntry(
                schemaVersion: schema.schemaVersion,
                fieldValues: validated
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
}

#Preview("New entry") {
    TapLogView(schema: try! SchemaConfig.load())
        .modelContainer(for: SymptomEntry.self, inMemory: true)
        .environment(\.theme, .plumEmber)
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
}
