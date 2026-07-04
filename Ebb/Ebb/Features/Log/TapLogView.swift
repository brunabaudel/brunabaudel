import SwiftUI

/// Tap logging surface — full schema chart, nothing pre-filled (Phase 2 wires save).
struct TapLogView: View {
    let schema: SchemaConfig
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: FieldValue] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Tap what applies. You can leave anything blank.")
                        .font(.footnote)
                        .foregroundStyle(theme.muted)

                    SchemaFormView(schema: schema, values: $values)
                }
                .padding(20)
            }
            .background(theme.base)
            .foregroundStyle(theme.text)
            .navigationTitle("Log symptoms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    TapLogView(schema: try! SchemaConfig.load())
        .environment(\.theme, .plumEmber)
}
