import SwiftUI

/// Day heat strip for the Today tab — one block per ~2¼ h from 6am through midnight.
struct TodayIntensityStrip: View {
    let entries: [SymptomEntry]
    var day: Date = .now
    var calendar: Calendar = .current

    @Environment(\.theme) private var theme

    private let blockCount = 8
    private let stripHeight: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Today's intensity")

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<blockCount, id: \.self) { index in
                    blockView(for: blocks[index])
                }
            }
            .frame(height: stripHeight, alignment: .bottom)

            HStack {
                ForEach(timeAxisLabels, id: \.self) { label in
                    Text(label)
                    if label != timeAxisLabels.last {
                        Spacer(minLength: 0)
                    }
                }
            }
            .font(.caption2.monospaced())
            .foregroundStyle(theme.muted.opacity(0.65))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private func blockView(for block: IntensityBlock) -> some View {
        ZStack(alignment: .bottom) {
            if let tip = block.tipLabel {
                Text(tip)
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.muted.opacity(0.65))
                    .fixedSize()
                    .offset(y: -stripHeight - 2)
            }

            RoundedRectangle(cornerRadius: 6)
                .fill(blockFill(for: block.kind))
                .opacity(blockOpacity(for: block.kind))
                .frame(maxWidth: .infinity)
                .frame(height: blockHeight(for: block.kind))
                .shadow(
                    color: blockGlow(for: block.kind),
                    radius: block.kind.isHighPain ? 5 : 0,
                    y: 0
                )
        }
        .frame(maxWidth: .infinity, minHeight: 8, maxHeight: stripHeight, alignment: .bottom)
    }

    private var blocks: [IntensityBlock] {
        Self.makeBlocks(
            entries: entries,
            day: day,
            calendar: calendar,
            blockCount: blockCount
        )
    }

    private var timeAxisLabels: [String] {
        ["6a", "12p", "6p", "12a"]
    }

    private func blockFill(for kind: IntensityBlock.Kind) -> Color {
        switch kind {
        case .empty: theme.line
        case .pain: theme.pain
        case .cycle: theme.cycle
        }
    }

    private func blockOpacity(for kind: IntensityBlock.Kind) -> Double {
        switch kind {
        case .empty: 1
        case .pain(let severity):
            switch severity {
            case 1, 2: 0.55
            case 3: 0.75
            default: 0.9
            }
        case .cycle: 0.5
        }
    }

    private func blockHeight(for kind: IntensityBlock.Kind) -> CGFloat {
        switch kind {
        case .empty: 8
        case .pain(let severity):
            switch severity {
            case 1, 2: 18
            case 3: 26
            default: 32
            }
        case .cycle: 14
        }
    }

    private func blockGlow(for kind: IntensityBlock.Kind) -> Color {
        guard kind.isHighPain else { return .clear }
        return theme.pain.opacity(0.45)
    }

    private var accessibilitySummary: String {
        let logged = blocks.filter { $0.kind != .empty }.count
        if logged == 0 {
            return "Today's intensity. No logs yet between 6 AM and midnight."
        }
        return "Today's intensity. \(logged) time blocks with symptoms logged."
    }

    private static func makeBlocks(
        entries: [SymptomEntry],
        day: Date,
        calendar: Calendar,
        blockCount: Int
    ) -> [IntensityBlock] {
        guard let dayStart = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: day),
              let dayEnd = calendar.date(byAdding: .hour, value: 18, to: dayStart) else {
            return Array(repeating: IntensityBlock(), count: blockCount)
        }

        var blocks = Array(repeating: IntensityBlock(), count: blockCount)
        let span = dayEnd.timeIntervalSince(dayStart)

        for entry in entries {
            guard entry.timestamp >= dayStart, entry.timestamp < dayEnd else { continue }
            let offset = entry.timestamp.timeIntervalSince(dayStart)
            let index = min(blockCount - 1, max(0, Int(offset / span * Double(blockCount))))

            if let severity = DaySummaryBuilder.painSeverity(for: entry) {
                if case .pain(let existing) = blocks[index].kind, existing >= severity {
                    continue
                }
                blocks[index].kind = .pain(severity: severity)
                blocks[index].tipLabel = compactTimeLabel(entry.timestamp, calendar: calendar)
            } else if DaySummaryBuilder.isCycleIntensityEntry(entry) {
                if case .pain = blocks[index].kind { continue }
                blocks[index].kind = .cycle
                blocks[index].tipLabel = compactTimeLabel(entry.timestamp, calendar: calendar)
            }
        }

        return blocks
    }

    private static func compactTimeLabel(_ date: Date, calendar: Calendar) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let isPM = hour >= 12
        let hour12 = hour % 12 == 0 ? 12 : hour % 12
        if minute == 0 {
            return "\(hour12)\(isPM ? "p" : "a")"
        }
        return date.formatted(date: .omitted, time: .shortened).lowercased()
    }
}

private struct IntensityBlock: Sendable {
    enum Kind: Equatable, Sendable {
        case empty
        case pain(severity: Int)
        case cycle

        var isHighPain: Bool {
            if case .pain(let severity) = self { return severity >= 4 }
            return false
        }
    }

    var kind: Kind = .empty
    var tipLabel: String?
}

#Preview {
    let schema = try! SchemaConfig.load()
    let migraine = SymptomEntry(
        timestamp: Calendar.current.date(bySettingHour: 21, minute: 8, second: 0, of: .now)!,
        schemaVersion: schema.schemaVersion,
        fieldValues: [
            "migraine_present": .boolean(true),
            "severity": .scale(4),
            "location": .choices(["right"]),
        ]
    )
    let spotting = SymptomEntry(
        timestamp: Calendar.current.date(bySettingHour: 14, minute: 15, second: 0, of: .now)!,
        schemaVersion: schema.schemaVersion,
        fieldValues: [
            "migraine_present": .boolean(false),
            "bleeding": .choice("spotting"),
            "cramps_severity": .scale(2),
        ],
        cyclePhase: .luteal
    )
    return TodayIntensityStrip(entries: [migraine, spotting])
        .padding()
        .background(Theme.plumEmber.base)
        .environment(\.theme, .plumEmber)
}
