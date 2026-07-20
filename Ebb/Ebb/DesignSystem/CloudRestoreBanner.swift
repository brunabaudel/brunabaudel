import SwiftUI

/// Shown while CloudKit may still be downloading entries after install or reinstall.
struct CloudRestoreBanner: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(theme.pain)

            VStack(alignment: .leading, spacing: 2) {
                Text("Restoring from iCloud")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.text)
                Text("Your logs appear here once the download finishes. Stay on Wi‑Fi if you can.")
                    .font(.caption)
                    .foregroundStyle(theme.muted)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.line)
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Restoring from iCloud. Your logs appear here once the download finishes.")
    }
}

#Preview {
    CloudRestoreBanner()
        .environment(\.theme, .plumEmber)
}
