import SwiftUI

/// A selectable pill used for enum and boolean field values.
struct SelectablePill: View {
    let label: String
    let isSelected: Bool
    var isHighlighted: Bool = false
    let accent: FieldAccent
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(backgroundColor, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(borderColor, lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) {
                    if isHighlighted {
                        Circle()
                            .fill(accent.accentColor(in: theme))
                            .frame(width: 8, height: 8)
                            .shadow(color: accent.accentColor(in: theme).opacity(0.6), radius: 4)
                            .offset(x: 3, y: -3)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(label)
    }

    private var foregroundColor: Color {
        if isSelected {
            accent.onAccentColor(in: theme)
        } else if isHighlighted {
            accent.accentColor(in: theme)
        } else {
            theme.muted
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            accent.accentColor(in: theme)
        } else if isHighlighted {
            accent.dimColor(in: theme)
        } else {
            .clear
        }
    }

    private var borderColor: Color {
        if isSelected || isHighlighted {
            accent.accentColor(in: theme)
        } else {
            theme.line
        }
    }
}

#Preview {
    HStack {
        SelectablePill(label: "Right side", isSelected: false, accent: .pain) {}
        SelectablePill(label: "Left side", isSelected: true, accent: .pain) {}
        SelectablePill(label: "Dull", isSelected: false, isHighlighted: true, accent: .pain) {}
    }
    .padding()
    .background(Theme.plumEmber.base)
    .environment(\.theme, .plumEmber)
}
