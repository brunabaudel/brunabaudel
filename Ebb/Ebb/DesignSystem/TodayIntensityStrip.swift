import SwiftUI

/// Day heat strip for the Today tab — one block per 3 h across the full calendar day.
struct TodayIntensityStrip: View {
    let entries: [SymptomEntry]
    @Binding var selectedBlockIndex: Int?
    var day: Date = .now
    var calendar: Calendar = .current

    @Environment(\.theme) private var theme

    static let blockCount = 8
    private let stripHeight: CGFloat = 36
    private let tipHeight: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Today's intensity")

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<Self.blockCount, id: \.self) { index in
                    blockButton(index: index, block: blocks[index])
                }
            }
            .frame(height: tipHeight + stripHeight, alignment: .bottom)

            HStack {
                ForEach(Array(timeAxisLabels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                    if index < timeAxisLabels.count - 1 {
                        Spacer(minLength: 0)
                    }
                }
            }
            .font(.caption2.monospaced())
            .foregroundStyle(theme.muted.opacity(0.65))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Today's intensity")
    }

    private func blockButton(index: Int, block: IntensityBlock) -> some View {
        let isSelected = selectedBlockIndex == index
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedBlockIndex = isSelected ? nil : index
            }
        } label: {
            VStack(spacing: 2) {
                Text(block.tipLabel ?? " ")
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .foregroundStyle(
                        block.tipLabel == nil
                            ? .clear
                            : theme.muted.opacity(isSelected ? 0.95 : 0.65)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(height: tipHeight)

                RoundedRectangle(cornerRadius: 6)
                    .fill(blockFill(for: block.kind))
                    .opacity(blockOpacity(for: block.kind))
                    .frame(maxWidth: .infinity)
                    .frame(height: blockHeight(for: block.kind), alignment: .bottom)
                    .frame(maxHeight: stripHeight, alignment: .bottom)
                    .shadow(
                        color: blockGlow(for: block.kind),
                        radius: block.kind.isHighPain ? 5 : 0,
                        y: 0
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                isSelected ? theme.muted.opacity(0.55) : Color.clear,
                                lineWidth: 1
                            )
                    }
            }
            .frame(maxWidth: .infinity, minHeight: tipHeight + stripHeight, alignment: .bottom)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(selectedBlockIndex == nil || isSelected ? 1 : 0.4)
        .accessibilityLabel(blockAccessibilityLabel(index: index, block: block))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityHint(
            isSelected
                ? "Showing logs for this time. Double tap to show all logs again."
                : "Double tap to show logs for this time."
        )
    }

    private var blocks: [IntensityBlock] {
        Self.makeBlocks(
            entries: entries,
            day: day,
            calendar: calendar,
            blockCount: Self.blockCount
        )
    }

    private var timeAxisLabels: [String] {
        ["12a", "6a", "12p", "6p", "12a"]
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

    private func blockAccessibilityLabel(index: Int, block: IntensityBlock) -> String {
        let range = Self.blockTimeRangeLabel(index: index, day: day, calendar: calendar)
        switch block.kind {
        case .empty:
            return "\(range). No symptoms logged."
        case .pain(let severity):
            return "\(range). Pain severity \(severity)."
        case .cycle:
            return "\(range). Cycle symptoms logged."
        }
    }

    // MARK: - Timeline helpers

    /// Entries whose timestamps fall in the given intensity block.
    static func entries(
        _ entries: [SymptomEntry],
        inBlock index: Int,
        day: Date = .now,
        calendar: Calendar = .current
    ) -> [SymptomEntry] {
        guard let range = blockDateRange(index: index, day: day, calendar: calendar) else {
            return []
        }
        return entries.filter { range.contains($0.timestamp) }
    }

    static func dayBounds(
        for day: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date)? {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }
        return (dayStart, dayEnd)
    }

    /// Block index containing `date` within that calendar day, if any.
    static func blockIndex(
        containing date: Date,
        day: Date = .now,
        calendar: Calendar = .current
    ) -> Int? {
        guard let bounds = dayBounds(for: day, calendar: calendar),
              date >= bounds.start, date < bounds.end else {
            return nil
        }
        let span = bounds.end.timeIntervalSince(bounds.start)
        let offset = date.timeIntervalSince(bounds.start)
        return min(blockCount - 1, max(0, Int(offset / span * Double(blockCount))))
    }

    static func blockDateRange(
        index: Int,
        day: Date = .now,
        calendar: Calendar = .current
    ) -> Range<Date>? {
        guard index >= 0, index < blockCount,
              let bounds = dayBounds(for: day, calendar: calendar) else {
            return nil
        }
        let span = bounds.end.timeIntervalSince(bounds.start)
        let blockSpan = span / Double(blockCount)
        let start = bounds.start.addingTimeInterval(Double(index) * blockSpan)
        let end = bounds.start.addingTimeInterval(Double(index + 1) * blockSpan)
        return start..<end
    }

    static func blockTimeRangeLabel(
        index: Int,
        day: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        guard let range = blockDateRange(index: index, day: day, calendar: calendar) else {
            return ""
        }
        let start = compactAxisTime(range.lowerBound, calendar: calendar)
        let end = compactAxisTime(range.upperBound, calendar: calendar)
        return "\(start)–\(end)"
    }

    private static func makeBlocks(
        entries: [SymptomEntry],
        day: Date,
        calendar: Calendar,
        blockCount: Int
    ) -> [IntensityBlock] {
        guard let bounds = dayBounds(for: day, calendar: calendar) else {
            return Array(repeating: IntensityBlock(), count: blockCount)
        }

        var blocks = Array(repeating: IntensityBlock(), count: blockCount)
        let span = bounds.end.timeIntervalSince(bounds.start)

        for entry in entries {
            guard entry.timestamp >= bounds.start, entry.timestamp < bounds.end else { continue }
            let offset = entry.timestamp.timeIntervalSince(bounds.start)
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

    private static func compactAxisTime(_ date: Date, calendar: Calendar) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let isPM = hour >= 12
        let hour12 = hour % 12 == 0 ? 12 : hour % 12
        if minute == 0 {
            return "\(hour12)\(isPM ? "p" : "a")"
        }
        return "\(hour12):\(String(format: "%02d", minute))\(isPM ? "p" : "a")"
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
    let overnight = SymptomEntry(
        timestamp: Calendar.current.date(bySettingHour: 2, minute: 30, second: 0, of: .now)!,
        schemaVersion: schema.schemaVersion,
        fieldValues: [
            "migraine_present": .boolean(true),
            "severity": .scale(3),
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
    return TodayIntensityStrip(
        entries: [migraine, overnight, spotting],
        selectedBlockIndex: .constant(0)
    )
    .padding()
    .background(Theme.plumEmber.base)
    .environment(\.theme, .plumEmber)
}
