import SwiftUI

struct MedicationsSettingsView: View {
    let schema: SchemaConfig
    @Bindable var medicationPreferences: MedicationPreferences

    @Environment(\.theme) private var theme

    private var reliefField: SchemaField? {
        schema.field(forKey: "relief_taken")
    }

    var body: some View {
        List {
            Section {
                Text("These appear pre-selected on the relief screen, so logging what you took is one tap.")
                    .font(.footnote)
                    .foregroundStyle(theme.muted)
                    .listRowBackground(theme.surface)
            }

            if let reliefField {
                Section {
                    ForEach(reliefField.values) { option in
                        Toggle(isOn: savedBinding(for: option.key)) {
                            Text(option.label)
                        }
                    }
                } header: {
                    Text(reliefField.label)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.base)
        .foregroundStyle(theme.text)
        .navigationTitle("My medications")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func savedBinding(for key: String) -> Binding<Bool> {
        Binding(
            get: { medicationPreferences.isSaved(key) },
            set: { medicationPreferences.setSaved(key, isSaved: $0) }
        )
    }
}

#Preview {
    NavigationStack {
        MedicationsSettingsView(
            schema: try! SchemaConfig.load(),
            medicationPreferences: MedicationPreferences()
        )
    }
    .environment(\.theme, .plumEmber)
}
