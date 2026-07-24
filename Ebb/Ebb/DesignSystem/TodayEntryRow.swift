import SwiftUI

/// Flat heat-row list item for today's logs (time, title, detail, accent dot).
struct TodayEntryRow: View {
    let entry: SymptomEntry
    let schema: SchemaConfig

    @Environment(\.theme) private var theme

    private var accent: FieldAccent {
        DaySummaryBuilder.entryAccent(entry)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption.monospaced())
                .foregroundStyle(theme.muted)
                .frame(width: 42, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(DaySummaryBuilder.todayRowTitle(entry, schema: schema))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let detail = DaySummaryBuilder.todayRowDetail(entry, schema: schema) {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(theme.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Circle()
                .fill(accent.accentColor(in: theme))
                .frame(width: 8, height: 8)
                .shadow(color: accent.accentColor(in: theme).opacity(0.85), radius: 3)
                .padding(.top, 5)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let title = DaySummaryBuilder.todayRowTitle(entry, schema: schema)
        let time = entry.timestamp.formatted(date: .omitted, time: .shortened)
        if let detail = DaySummaryBuilder.todayRowDetail(entry, schema: schema) {
            return "\(title), \(time). \(detail)"
        }
        return "\(title), \(time)"
    }
}

#Preview {
    let schema = try! SchemaConfig.load()
    let entry = SymptomEntry(
        schemaVersion: schema.schemaVersion,
        fieldValues: [
            "migraine_present": .boolean(true),
            "severity": .scale(4),
            "location": .choices(["right"]),
            "associated_symptoms": .choices(["nausea"]),
            "relief_taken": .choices(["ibuprofen"]),
        ]
    )
    return TodayEntryRow(entry: entry, schema: schema)
        .padding(.horizontal)
        .background(Theme.plumEmber.base)
        .environment(\.theme, .plumEmber)
}
