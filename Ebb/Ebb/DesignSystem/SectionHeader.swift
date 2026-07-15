import SwiftUI

/// Uppercase section label used across symptom forms and feature screens.
struct SectionHeader: View {
    let title: String

    @Environment(\.theme) private var theme

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .kerning(1.5)
            .foregroundStyle(theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    SectionHeader(title: "Migraine")
        .padding()
        .background(Theme.plumEmber.base)
        .environment(\.theme, .plumEmber)
}
