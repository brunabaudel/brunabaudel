import SwiftUI

/// Segmented scale control for 0–5 and 1–5 schema fields.
struct ScaleStepper: View {
    let range: ClosedRange<Int>
    let labels: [Int: String]
    @Binding var selection: Int?
    var isHighlighted: Bool = false
    let accent: FieldAccent

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(Array(range), id: \.self) { step in
                    scaleButton(for: step)
                }
            }

            if let selection, let caption = labels[selection] {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(theme.muted)
                    .italic()
                    .accessibilityHidden(true)
            }
        }
    }

    private func scaleButton(for step: Int) -> some View {
        let isSelected = selection == step
        let isFilled = selection.map { step <= $0 && range.lowerBound > 0 } ?? false

        return Button {
            selection = isSelected ? nil : step
        } label: {
            Text("\(step)")
                .font(.caption.monospaced())
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .foregroundStyle(isSelected ? accent.onAccentColor(in: theme) : theme.muted)
                .background {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(background(for: step, isSelected: isSelected, isFilled: isFilled))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(border(for: step, isSelected: isSelected, isFilled: isFilled), lineWidth: 1)
                }
                .shadow(
                    color: isSelected && isHighlighted ? accent.accentColor(in: theme).opacity(0.45) : .clear,
                    radius: 7
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: step, isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func background(for step: Int, isSelected: Bool, isFilled: Bool) -> Color {
        if isSelected {
            accent.accentColor(in: theme)
        } else if isFilled {
            accent.dimColor(in: theme)
        } else {
            .clear
        }
    }

    private func border(for step: Int, isSelected: Bool, isFilled: Bool) -> Color {
        if isSelected || isFilled {
            accent.accentColor(in: theme)
        } else {
            theme.line
        }
    }

    private func accessibilityLabel(for step: Int, isSelected: Bool) -> String {
        let caption = labels[step].map { ", \($0)" } ?? ""
        return isSelected ? "Level \(step)\(caption), selected" : "Level \(step)\(caption)"
    }
}

#Preview {
    @Previewable @State var severity: Int? = 2
    ScaleStepper(range: 1...5, labels: [1: "barely there", 2: "mild"], selection: $severity, accent: .pain)
        .padding()
        .background(Theme.plumEmber.base)
        .environment(\.theme, .plumEmber)
}
