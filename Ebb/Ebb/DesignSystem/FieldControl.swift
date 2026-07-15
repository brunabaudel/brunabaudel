import SwiftUI

/// Renders any schema field as the correct control type. Adding a value to
/// `symptom-schema.json` makes a new pill appear here with zero Swift changes.
struct FieldControl: View {
    let field: SchemaField
    @Binding var value: FieldValue?
    var highlightedValues: Set<String> = []
    var accent: FieldAccent?

    @Environment(\.theme) private var theme

    private var resolvedAccent: FieldAccent {
        accent ?? field.accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(field.label.uppercased())
                .font(.caption2.weight(.semibold))
                .kerning(1.2)
                .foregroundStyle(theme.muted)
                .accessibilityHidden(true)

            switch field.type {
            case .boolean:
                booleanControl
            case .scale:
                scaleControl
            case .singleEnum:
                singleEnumControl
            case .multiEnum:
                multiEnumControl
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(field.label)
    }

    // MARK: - Boolean

    private var booleanControl: some View {
        HStack(spacing: 7) {
            SelectablePill(
                label: "Yes",
                isSelected: value == .boolean(true),
                isHighlighted: highlightedValues.contains("true"),
                accent: resolvedAccent
            ) {
                value = value == .boolean(true) ? nil : .boolean(true)
            }
            SelectablePill(
                label: "No",
                isSelected: value == .boolean(false),
                isHighlighted: highlightedValues.contains("false"),
                accent: resolvedAccent
            ) {
                value = value == .boolean(false) ? nil : .boolean(false)
            }
        }
    }

    // MARK: - Scale

    @ViewBuilder
    private var scaleControl: some View {
        if let range = field.range {
            ScaleStepper(
                range: range,
                labels: field.scaleLabels,
                selection: scaleBinding,
                isHighlighted: !highlightedValues.isEmpty,
                accent: resolvedAccent
            )
        }
    }

    private var scaleBinding: Binding<Int?> {
        Binding(
            get: {
                if case .scale(let step)? = value { return step }
                return nil
            },
            set: { newValue in
                value = newValue.map { .scale($0) }
            }
        )
    }

    // MARK: - Single enum

    private var singleEnumControl: some View {
        FlowLayout(spacing: 7) {
            ForEach(field.values) { option in
                SelectablePill(
                    label: option.label,
                    isSelected: value == .choice(option.key),
                    isHighlighted: highlightedValues.contains(option.key),
                    accent: resolvedAccent
                ) {
                    value = value == .choice(option.key) ? nil : .choice(option.key)
                }
            }
        }
    }

    // MARK: - Multi enum

    private var multiEnumControl: some View {
        FlowLayout(spacing: 7) {
            ForEach(field.values) { option in
                SelectablePill(
                    label: option.label,
                    isSelected: selectedChoices.contains(option.key),
                    isHighlighted: highlightedValues.contains(option.key),
                    accent: resolvedAccent
                ) {
                    toggleChoice(option.key)
                }
            }
        }
    }

    private var selectedChoices: Set<String> {
        Set(orderedChoices)
    }

    private var orderedChoices: [String] {
        if case .choices(let keys)? = value { return keys }
        return []
    }

    private func toggleChoice(_ key: String) {
        var choices = orderedChoices
        if let index = choices.firstIndex(of: key) {
            choices.remove(at: index)
        } else {
            choices.append(key)
        }
        value = choices.isEmpty ? nil : .choices(choices)
    }
}

// MARK: - Flow layout for pills

/// Wraps pill controls onto multiple lines without hard-coding field widths.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> Arrangement {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return Arrangement(
            size: CGSize(width: maxWidth, height: totalHeight),
            positions: positions
        )
    }

    private struct Arrangement {
        let size: CGSize
        let positions: [CGPoint]
    }
}

#Preview {
    @Previewable @State var values: [String: FieldValue] = [:]
    let schema = try! SchemaConfig.load()

    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(schema.fields) { field in
                FieldControl(
                    field: field,
                    value: Binding(
                        get: { values[field.key] },
                        set: { values[field.key] = $0 }
                    )
                )
            }
        }
        .padding()
    }
    .background(Theme.plumEmber.base)
    .environment(\.theme, .plumEmber)
}
