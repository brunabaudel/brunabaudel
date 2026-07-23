import SwiftData
import SwiftUI

struct PatternsView: View {
    let schema: SchemaConfig

    @Environment(\.theme) private var theme
    @Environment(CycleService.self) private var cycleService
    @Environment(EntitlementsService.self) private var entitlements
    @Query(sort: \SymptomEntry.timestamp, order: .reverse) private var entries: [SymptomEntry]

    @State private var showPaywall = false

    private var overlay: CalendarCycleOverlay {
        cycleService.makeOverlay(from: entries)
    }

    private var report: PatternStatsEngine.Report {
        PatternStatsEngine.buildReport(
            entries: entries,
            schema: schema,
            overlay: overlay
        )
    }

    private var shouldGatePatterns: Bool {
        !entitlements.isEbbPlus
            && report.hasCycleData
            && report.migraineCountThisCycle > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if shouldGatePatterns {
                    PatternsPaywallView {
                        showPaywall = true
                    }
                } else if report.hasCycleData && report.migraineCountThisCycle > 0 {
                    populatedContent
                } else if report.hasCycleData {
                    waitingForMigrainesContent
                } else {
                    emptyContent
                }
            }
            .background(theme.base)
            .foregroundStyle(theme.text)
            .navigationTitle("Patterns")
            .sheet(isPresented: $showPaywall) {
                EbbPlusPaywallSheet()
            }
        }
    }

    // MARK: - Populated

    private var populatedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("This cycle")
                .font(.system(.title2, design: .serif))
                .padding(.horizontal, 20)
                .padding(.top, 8)

            timelineCard
                .padding(.horizontal, 20)
                .padding(.top, 18)

            if !report.topTriggers.isEmpty {
                triggersSection
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
            }

            if let insight = report.insight {
                insightCard(insight)
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
            }

            if !report.reliefEffectiveness.isEmpty {
                reliefSection
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
            }
        }
        .padding(.bottom, 24)
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(attributedCaption(report.timelineCaption))
                .font(.footnote)
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            CycleTimelineView(timeline: report.timeline)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(theme.line, lineWidth: 1)
        }
    }

    private var triggersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Most-logged triggers")
            ForEach(report.topTriggers, id: \.key) { item in
                triggerBar(item)
            }
        }
    }

    private func triggerBar(_ item: PatternStatsEngine.RankedCount) -> some View {
        HStack(spacing: 11) {
            Text(item.label)
                .font(.footnote)
                .frame(width: 92, alignment: .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(theme.line.opacity(0.45))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [theme.painDim, theme.pain],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(proxy.size.width * item.fraction, item.count > 0 ? 6 : 0))
                }
            }
            .frame(height: 8)

            Text("\(item.count)")
                .font(.caption.monospaced())
                .foregroundStyle(theme.muted)
                .frame(width: 24, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.label), \(item.count) times")
    }

    private func insightCard(_ text: String) -> some View {
        Text(attributedInsight(text))
            .font(.subheadline)
            .foregroundStyle(theme.text)
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(theme.line, lineWidth: 1)
            }
    }

    private var reliefSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Relief effectiveness")
            ForEach(report.reliefEffectiveness, id: \.key) { stat in
                HStack {
                    Text(stat.label)
                        .font(.footnote)
                    Spacer()
                    Text(reliefSummary(stat))
                        .font(.caption.monospaced())
                        .foregroundStyle(theme.muted)
                }
            }
        }
    }

    private func reliefSummary(_ stat: PatternStatsEngine.ReliefStat) -> String {
        if stat.timesHelpful == 0 {
            return "\(stat.timesTaken)× logged"
        }
        let pct = Int((stat.helpfulFraction * 100).rounded())
        return "\(stat.timesHelpful)/\(stat.timesTaken) helped (\(pct)%)"
    }

    // MARK: - Empty states

    private var waitingForMigrainesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This cycle")
                .font(.system(.title2, design: .serif))

            Text(report.timelineCaption)
                .font(.subheadline)
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            CycleTimelineView(timeline: report.timeline)
                .padding(18)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(theme.line, lineWidth: 1)
                }

            Text("Patterns appear after a cycle or two of logging.")
                .font(.footnote)
                .foregroundStyle(theme.muted)
        }
        .padding(20)
    }

    private var emptyContent: some View {
        ContentUnavailableView {
            Label("Patterns", systemImage: "chart.line.uptrend.xyaxis")
        } description: {
            Text(report.timelineCaption)
        } actions: {
            Text("Patterns appear after a cycle or two of logging.")
                .font(.footnote)
                .foregroundStyle(theme.muted)
        }
    }

    // MARK: - Attributed text

    private func attributedCaption(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        if let range = result.range(of: "luteal phase", options: .caseInsensitive) {
            result[range].foregroundColor = theme.cycle
            result[range].font = .footnote.weight(.semibold)
        }
        return result
    }

    private func attributedInsight(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        for trigger in report.topTriggers.prefix(1) {
            let phrase = trigger.label.lowercased()
            if let range = result.range(of: phrase) {
                result[range].font = .subheadline.weight(.semibold)
            }
        }
        return result
    }
}

#Preview("With patterns") {
    let schema = try! SchemaConfig.load()
    let container = try! ModelContainer(
        for: SymptomEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let cal = Calendar.ebbCalendar
    let periodStart = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!

    let migraineDays = [17, 20, 25]
    for (index, day) in migraineDays.enumerated() {
        let date = cal.date(byAdding: .day, value: day - 1, to: periodStart)!
        container.mainContext.insert(SymptomEntry(
            timestamp: cal.date(bySettingHour: 20, minute: 0, second: 0, of: date)!,
            schemaVersion: schema.schemaVersion,
            fieldValues: [
                "migraine_present": .boolean(true),
                "severity": .scale(3),
                "location": .choices(["right"]),
                "triggers": .choices(index == 0 ? ["poor_sleep"] : ["poor_sleep", "stress"]),
            ],
            cyclePhase: .luteal
        ))
    }
    container.mainContext.insert(SymptomEntry(
        timestamp: periodStart,
        schemaVersion: schema.schemaVersion,
        fieldValues: ["bleeding": .choice("medium")]
    ))

    return PatternsView(schema: schema)
        .modelContainer(container)
        .environment(\.theme, .plumEmber)
        .environment(CycleService(provider: MockCycleDataProvider()))
        .environment(EntitlementsService(previewIsEbbPlus: false, listenForUpdates: false))
}

#Preview("Empty") {
    PatternsView(schema: try! SchemaConfig.load())
        .modelContainer(for: SymptomEntry.self, inMemory: true)
        .environment(\.theme, .plumEmber)
        .environment(CycleService(provider: MockCycleDataProvider()))
        .environment(EntitlementsService(previewIsEbbPlus: false, listenForUpdates: false))
}
