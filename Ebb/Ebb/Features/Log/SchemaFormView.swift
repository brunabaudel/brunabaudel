import SwiftUI

/// Full symptom chart rendered from the bundled schema. Every field and pill
/// comes from `symptom-schema.json`; progressive disclosure follows `appliesWhen`.
struct SchemaFormView: View {
    let schema: SchemaConfig
    @Binding var values: [String: FieldValue]
    var highlightedFields: [String: Set<String>] = [:]

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(visibleFields) { field in
                FieldControl(
                    field: field,
                    value: binding(for: field.key),
                    highlightedValues: highlightedFields[field.key, default: []]
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: visibleFieldKeys)
    }

    private var visibleFields: [SchemaField] {
        schema.fields.filter { AppliesWhenEvaluator.isVisible(field: $0, values: values) }
    }

    private var visibleFieldKeys: [String] {
        visibleFields.map(\.key)
    }

    private func binding(for key: String) -> Binding<FieldValue?> {
        Binding(
            get: { values[key] },
            set: { newValue in
                if let newValue {
                    values[key] = newValue
                } else {
                    values.removeValue(forKey: key)
                }
            }
        )
    }
}

#Preview {
    @Previewable @State var values: [String: FieldValue] = ["migraine_present": .boolean(true)]
    SchemaFormView(schema: try! SchemaConfig.load(), values: $values)
        .padding()
        .background(Theme.plumEmber.base)
        .environment(\.theme, .plumEmber)
}
