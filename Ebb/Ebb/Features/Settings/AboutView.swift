import SwiftUI

struct AboutView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("About Ebb")
                    .font(.system(.title2, design: .serif))

                Text(MedicalDisclaimer.body)
                    .font(.body)
                    .foregroundStyle(theme.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text(MedicalDisclaimer.shortLine)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.cycle)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Ebb stores your logs on this device. Optional iCloud backup uses your private Apple ID database — Ebb never sees your data.")
                    .font(.footnote)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.base)
        .foregroundStyle(theme.text)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
    .environment(\.theme, .plumEmber)
}
