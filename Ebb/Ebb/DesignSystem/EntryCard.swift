import SwiftUI

/// Compact summary of one logged entry, reused on Today and Calendar.
struct EntryCard: View {
    let entry: SymptomEntry
    let schema: SchemaConfig

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            iconBadge
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let severity = severityLabel {
                Text(severity)
                    .font(.caption2.monospaced())
                    .foregroundStyle(theme.pain)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(theme.painDim, in: RoundedRectangle(cornerRadius: 7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(theme.pain.opacity(0.35), lineWidth: 1)
                    }
            }
        }
        .padding(11)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(theme.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)\(severityLabel.map { ", severity \($0)" } ?? "")")
    }

    private var iconBadge: some View {
        Text(icon)
            .font(.body)
            .frame(width: 30, height: 30)
            .background(theme.painDim, in: RoundedRectangle(cornerRadius: 9))
            .accessibilityHidden(true)
    }

    private var icon: String {
        if entry.fieldValues["migraine_present"] == .boolean(true) {
            return "🤕"
        }
        if entry.fieldValues["bleeding"] != nil {
            return "🩸"
        }
        return "📝"
    }

    private var title: String {
        if entry.fieldValues["migraine_present"] == .boolean(true) {
            return "Migraine"
        }
        if let bleeding = entry.fieldValues["bleeding"],
           case .choice(let key) = bleeding,
           let label = schema.field(forKey: "bleeding")?.values.first(where: { $0.key == key })?.label {
            return label
        }
        return "Symptom log"
    }

    private var subtitle: String {
        entry.timestamp.formatted(date: .omitted, time: .shortened)
    }

    private var severityLabel: String? {
        guard case .scale(let step)? = entry.fieldValues["severity"] else { return nil }
        return "\(step)/5"
    }
}

#Preview {
    let schema = try! SchemaConfig.load()
    let entry = SymptomEntry(
        schemaVersion: schema.schemaVersion,
        fieldValues: [
            "migraine_present": .boolean(true),
            "severity": .scale(3),
            "location": .choices(["right"]),
        ]
    )
    EntryCard(entry: entry, schema: schema)
        .padding()
        .background(Theme.plumEmber.base)
        .environment(\.theme, .plumEmber)
}
