import SwiftUI
import SwiftData

/// Phase 0 verification surface: every schema field rendered as text, swatches
/// for every theme, and a live SwiftData round-trip check. Not shipped past
/// Phase 0 — replaced by the real tab scaffold in Phase 1.
struct DebugScreen: View {
    let schemaLoadResult: Result<SchemaConfig, Error>

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @State private var roundTripOutcome: StorageRoundTripCheck.Outcome?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                schemaSection
                themesSection
                storageSection
            }
            .padding(20)
        }
        .background(theme.base)
        .foregroundStyle(theme.text)
    }

    // MARK: Schema

    @ViewBuilder
    private var schemaSection: some View {
        sectionHeader("Schema")
        switch schemaLoadResult {
        case .success(let schema):
            Text("v\(schema.schemaVersion) · \(schema.domain) · \(schema.fields.count) fields")
                .font(.footnote)
                .foregroundStyle(theme.muted)
            ForEach(schema.fields) { field in
                fieldCard(field)
            }
        case .failure(let error):
            Text("Schema failed to load: \(error.localizedDescription)")
                .font(.callout)
                .foregroundStyle(theme.pain)
        }
    }

    private func fieldCard(_ field: SchemaField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(field.label)
                    .font(.headline)
                Spacer()
                Text(field.type.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(theme.cycle)
            }
            Text(field.key)
                .font(.caption.monospaced())
                .foregroundStyle(theme.muted)
            if let range = field.range {
                Text("\(range.lowerBound)–\(range.upperBound)"
                     + (field.scaleLabels.isEmpty ? "" : "  (\(scaleLabelSummary(field)))"))
                    .font(.caption)
                    .foregroundStyle(theme.muted)
            }
            if !field.values.isEmpty {
                Text(field.values.map(\.label).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(theme.text)
            }
            if let appliesWhen = field.appliesWhen {
                Text("when: \(appliesWhen)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(theme.surface, in: .rect(cornerRadius: 14))
    }

    private func scaleLabelSummary(_ field: SchemaField) -> String {
        field.scaleLabels
            .sorted { $0.key < $1.key }
            .map { "\($0.key) \($0.value)" }
            .joined(separator: ", ")
    }

    // MARK: Themes

    @ViewBuilder
    private var themesSection: some View {
        sectionHeader("Themes")
        ForEach(Theme.all) { candidate in
            VStack(alignment: .leading, spacing: 8) {
                Text(candidate.name)
                    .font(.headline)
                HStack(spacing: 6) {
                    swatch(candidate.base)
                    swatch(candidate.surface)
                    swatch(candidate.line)
                    swatch(candidate.text)
                    swatch(candidate.muted)
                    swatch(candidate.pain)
                    swatch(candidate.painDim)
                    swatch(candidate.onPain)
                    swatch(candidate.cycle)
                    swatch(candidate.cycleDim)
                    swatch(candidate.ok)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: .rect(cornerRadius: 14))
        }
    }

    private func swatch(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(color)
            .strokeBorder(theme.line)
            .frame(width: 24, height: 24)
    }

    // MARK: Storage

    @ViewBuilder
    private var storageSection: some View {
        sectionHeader("Storage")
        if case .success(let schema) = schemaLoadResult {
            Button("Run SwiftData round-trip") {
                roundTripOutcome = StorageRoundTripCheck.run(
                    in: modelContext.container,
                    schema: schema
                )
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(theme.onPain)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(theme.pain, in: .rect(cornerRadius: 13))

            switch roundTripOutcome {
            case .passed:
                Text("Round-trip passed")
                    .font(.callout)
                    .foregroundStyle(theme.ok)
            case .failed(let reason):
                Text("Round-trip failed: \(reason)")
                    .font(.callout)
                    .foregroundStyle(theme.pain)
            case nil:
                EmptyView()
            }
        } else {
            Text("Unavailable without a loaded schema")
                .font(.callout)
                .foregroundStyle(theme.muted)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .kerning(1.5)
            .foregroundStyle(theme.muted)
    }
}

#Preview {
    DebugScreen(schemaLoadResult: Result { try SchemaConfig.load() })
        .environment(\.theme, .plumEmber)
        .modelContainer(for: SymptomEntry.self, inMemory: true)
}
