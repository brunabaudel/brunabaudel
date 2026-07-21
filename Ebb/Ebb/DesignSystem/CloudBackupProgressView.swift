import SwiftUI

/// Step-based backup progress. CloudKit does not expose byte-level upload progress.
struct CloudBackupProgressView: View {
    @Environment(\.theme) private var theme

    let phaseLabel: String
    let progress: Double
    let verificationStep: Int
    let verificationStepCount: Int
    let isIndeterminate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(phaseLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.text)
                Spacer(minLength: 8)
                if verificationStep > 0, verificationStepCount > 0, !isIndeterminate {
                    Text("Step \(verificationStep) of \(verificationStepCount)")
                        .font(.caption)
                        .foregroundStyle(theme.muted)
                }
            }

            if isIndeterminate {
                ProgressView()
                    .tint(theme.ok)
            } else {
                ProgressView(value: progress)
                    .tint(theme.ok)
            }

            Text(progressCaption)
                .font(.caption)
                .foregroundStyle(theme.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(phaseLabel). \(progressCaption)")
    }

    private var progressCaption: String {
        if isIndeterminate {
            return "Waiting for iCloud to start the upload."
        }
        let percent = Int((progress * 100).rounded())
        if percent >= 99, progress < 1 {
            return "\(percent)% — still confirming. Stay on Wi‑Fi and keep Ebb open."
        }
        return "\(percent)% — stay on Wi‑Fi until this reaches 100%."
    }
}

#Preview("Uploading") {
    CloudBackupProgressView(
        phaseLabel: "Uploading to iCloud…",
        progress: 0.45,
        verificationStep: 0,
        verificationStepCount: 5,
        isIndeterminate: false
    )
    .padding()
    .environment(\.theme, .plumEmber)
}

#Preview("Confirming") {
    CloudBackupProgressView(
        phaseLabel: "Confirming in iCloud…",
        progress: 0.92,
        verificationStep: 4,
        verificationStepCount: 5,
        isIndeterminate: false
    )
    .padding()
    .environment(\.theme, .plumEmber)
}
