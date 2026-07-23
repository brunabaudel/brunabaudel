import Foundation

/// Multi-cycle report synthesis for the doctor PDF (build-plan Phase 11).
/// Pure Swift — reuses `PatternStatsEngine` entry helpers where possible.
enum DoctorReportEngine {
    // MARK: - Public types

    struct Report: Equatable, Sendable {
        let hasEnoughData: Bool
        let dateRangeLabel: String
        let dateRangeStart: Date
        let dateRangeEnd: Date
        let summaryLine: String
        let avgMigrainesPerCycle: Double?
        let avgSeverity: Double?
        let lutealPercentage: Int?
        let phaseCounts: [PhaseCount]
        let topTriggers: [PatternStatsEngine.RankedCount]
        let reliefSummaries: [ReliefSummary]
        let auraSummary: String
        let cycleSummary: String
        let cycleCount: Int
        let migraineCount: Int
        let totalEntryCount: Int
        let timelineEvents: [TimelineEvent]
    }

    struct PhaseCount: Equatable, Sendable {
        let phase: CyclePhase
        let count: Int
        let fraction: Double
    }

    struct ReliefSummary: Equatable, Sendable {
        let label: String
        let detail: String
    }

    struct TimelineEvent: Equatable, Sendable {
        let date: Date
        let cycleDay: Int?
        let phase: CyclePhase?
        let severity: Int?
    }

    // MARK: - Build

    static func buildReport(
        entries: [SymptomEntry],
        schema: SchemaConfig,
        overlay: CalendarCycleOverlay,
        hasAuraPreference: Bool,
        typicalCycleLength: Int,
        now: Date = .now
    ) -> Report {
        let migraineEntries = entries
            .filter(PatternStatsEngine.isMigraine)
            .sorted { $0.timestamp < $1.timestamp }

        guard !migraineEntries.isEmpty else {
            return emptyReport(
                totalEntryCount: entries.count,
                typicalCycleLength: typicalCycleLength,
                hasAuraPreference: hasAuraPreference,
                now: now
            )
        }

        let rangeStart = migraineEntries.first!.timestamp
        let rangeEnd = migraineEntries.last!.timestamp
        let cycleStarts = cycleStarts(for: migraineEntries, overlay: overlay)
        let cycleCount = max(cycleStarts.count, 1)

        let phaseCounts = phaseFrequency(from: migraineEntries, overlay: overlay)
        let lutealCount = phaseCounts.first { $0.phase == .luteal }?.count ?? 0
        let lutealPercentage = migraineEntries.isEmpty
            ? nil
            : Int((Double(lutealCount) / Double(migraineEntries.count) * 100).rounded())

        let topTriggers = PatternStatsEngine.rankedTriggers(
            from: migraineEntries,
            schema: schema,
            limit: 6
        )
        let reliefSummaries = reliefSummaries(
            from: migraineEntries,
            schema: schema
        )

        return Report(
            hasEnoughData: true,
            dateRangeLabel: dateRangeLabel(
                from: rangeStart,
                to: rangeEnd,
                calendar: overlay.calendar
            ),
            dateRangeStart: rangeStart,
            dateRangeEnd: rangeEnd,
            summaryLine: summaryLine(
                migraineEntries: migraineEntries,
                overlay: overlay,
                schema: schema,
                hasAuraPreference: hasAuraPreference,
                phaseCounts: phaseCounts
            ),
            avgMigrainesPerCycle: Double(migraineEntries.count) / Double(cycleCount),
            avgSeverity: averageSeverity(from: migraineEntries),
            lutealPercentage: lutealPercentage,
            phaseCounts: phaseCounts,
            topTriggers: topTriggers,
            reliefSummaries: reliefSummaries,
            auraSummary: auraSummary(
                migraineEntries: migraineEntries,
                schema: schema,
                hasAuraPreference: hasAuraPreference
            ),
            cycleSummary: "~\(typicalCycleLength) days",
            cycleCount: cycleCount,
            migraineCount: migraineEntries.count,
            totalEntryCount: entries.count,
            timelineEvents: timelineEvents(from: migraineEntries, overlay: overlay)
        )
    }

    // MARK: - Formatting helpers

    static func triggersLine(from triggers: [PatternStatsEngine.RankedCount]) -> String {
        guard !triggers.isEmpty else { return "None logged" }
        return triggers.map(\.label).joined(separator: ", ")
    }

    static func reliefLine(from summaries: [ReliefSummary]) -> String {
        guard !summaries.isEmpty else { return "None logged" }
        return summaries.map { "\($0.label) (\($0.detail))" }.joined(separator: ", ")
    }

    static func formattedAverage(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    // MARK: - Private builders

    private static func emptyReport(
        totalEntryCount: Int,
        typicalCycleLength: Int,
        hasAuraPreference: Bool,
        now: Date
    ) -> Report {
        Report(
            hasEnoughData: false,
            dateRangeLabel: dateRangeLabel(from: now, to: now, calendar: .ebbCalendar),
            dateRangeStart: now,
            dateRangeEnd: now,
            summaryLine: "Log a migraine to build a summary for your doctor.",
            avgMigrainesPerCycle: nil,
            avgSeverity: nil,
            lutealPercentage: nil,
            phaseCounts: [],
            topTriggers: [],
            reliefSummaries: [],
            auraSummary: hasAuraPreference ? "Reports aura" : "None reported",
            cycleSummary: "~\(typicalCycleLength) days",
            cycleCount: 0,
            migraineCount: 0,
            totalEntryCount: totalEntryCount,
            timelineEvents: []
        )
    }

    private static func cycleStarts(
        for migraineEntries: [SymptomEntry],
        overlay: CalendarCycleOverlay
    ) -> Set<Date> {
        Set(
            migraineEntries.compactMap { entry in
                overlay.periodStart(containing: entry.timestamp)
                    .map { overlay.calendar.startOfDay(for: $0) }
            }
        )
    }

    private static func phaseFrequency(
        from migraineEntries: [SymptomEntry],
        overlay: CalendarCycleOverlay
    ) -> [PhaseCount] {
        let phases = migraineEntries.compactMap {
            PatternStatsEngine.resolvedPhase(for: $0, overlay: overlay)
        }
        guard !phases.isEmpty else { return [] }

        let grouped = Dictionary(grouping: phases, by: { $0 }).mapValues(\.count)
        let maxCount = grouped.values.max() ?? 0
        guard maxCount > 0 else { return [] }

        return CyclePhase.allCases.compactMap { phase in
            guard let count = grouped[phase], count > 0 else { return nil }
            return PhaseCount(
                phase: phase,
                count: count,
                fraction: Double(count) / Double(maxCount)
            )
        }
    }

    private static func averageSeverity(from migraineEntries: [SymptomEntry]) -> Double? {
        let values = migraineEntries.compactMap { entry -> Int? in
            guard case .scale(let value) = entry.fieldValues["severity"] else { return nil }
            return value
        }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    private static func timelineEvents(
        from migraineEntries: [SymptomEntry],
        overlay: CalendarCycleOverlay
    ) -> [TimelineEvent] {
        migraineEntries.map { entry in
            TimelineEvent(
                date: entry.timestamp,
                cycleDay: overlay.cycleDay(for: entry.timestamp),
                phase: PatternStatsEngine.resolvedPhase(for: entry, overlay: overlay),
                severity: {
                    guard case .scale(let value) = entry.fieldValues["severity"] else { return nil }
                    return value
                }()
            )
        }
    }

    private static func reliefSummaries(
        from migraineEntries: [SymptomEntry],
        schema: SchemaConfig
    ) -> [ReliefSummary] {
        var taken: [String: Int] = [:]
        var effects: [String: [String: Int]] = [:]

        for entry in migraineEntries {
            let keys = PatternStatsEngine.reliefKeys(from: entry)
            guard !keys.isEmpty else { continue }

            var effectKey = "none"
            if case .choice(let key) = entry.fieldValues["relief_effect"] {
                effectKey = key
            }

            for key in keys {
                taken[key, default: 0] += 1
                effects[key, default: [:]][effectKey, default: 0] += 1
            }
        }

        let reliefField = schema.field(forKey: "relief_taken")
        return taken.sorted { $0.value > $1.value }.map { key, _ in
            let topEffect = effects[key]?.max(by: { $0.value < $1.value })?.key ?? "none"
            return ReliefSummary(
                label: reliefField?.values.first { $0.key == key }?.label ?? key,
                detail: reliefEffectDetail(for: topEffect)
            )
        }
    }

    private static func reliefEffectDetail(for effectKey: String) -> String {
        switch effectKey {
        case "partial": "partial"
        case "full": "helped"
        case "none": "no relief"
        default: effectKey
        }
    }

    private static func auraSummary(
        migraineEntries: [SymptomEntry],
        schema: SchemaConfig,
        hasAuraPreference: Bool
    ) -> String {
        var loggedAuraLabels: [String] = []
        for entry in migraineEntries {
            guard case .choices(let keys) = entry.fieldValues["aura"] else { continue }
            for key in keys where key != "none" {
                if let label = schema.field(forKey: "aura")?.values.first(where: { $0.key == key })?.label {
                    loggedAuraLabels.append(label.lowercased())
                }
            }
        }

        let uniqueLogged = Array(Set(loggedAuraLabels)).sorted()
        if !uniqueLogged.isEmpty {
            return uniqueLogged.joined(separator: ", ")
        }
        if hasAuraPreference {
            return "Reports aura (not logged on individual entries)"
        }
        return "None reported"
    }

    private static func summaryLine(
        migraineEntries: [SymptomEntry],
        overlay: CalendarCycleOverlay,
        schema: SchemaConfig,
        hasAuraPreference: Bool,
        phaseCounts: [PhaseCount]
    ) -> String {
        var segments: [String] = []

        if let dominant = phaseCounts.max(by: { $0.count < $1.count }),
           dominant.count > migraineEntries.count / 2 {
            switch dominant.phase {
            case .luteal:
                segments.append("Migraines cluster in the luteal phase")
                if let timing = lutealOnsetHint(from: migraineEntries, overlay: overlay) {
                    segments[0] += " — \(timing)"
                }
            case .menstrual:
                segments.append("Migraines cluster during bleeding")
            case .follicular:
                segments.append("Migraines cluster in the follicular phase")
            case .ovulation:
                segments.append("Migraines cluster around ovulation")
            }
        }

        if let location = dominantLocation(from: migraineEntries, schema: schema) {
            segments.append(location)
        }

        let auraPhrase = auraPhraseForSummary(
            migraineEntries: migraineEntries,
            schema: schema,
            hasAuraPreference: hasAuraPreference
        )
        segments.append(auraPhrase)

        if segments.isEmpty {
            return "Migraine pattern summary across \(migraineEntries.count) logged attacks."
        }

        return segments.joined(separator: ", ") + "."
    }

    private static func lutealOnsetHint(
        from migraineEntries: [SymptomEntry],
        overlay: CalendarCycleOverlay
    ) -> String? {
        let lutealEntries = migraineEntries.filter {
            PatternStatsEngine.resolvedPhase(for: $0, overlay: overlay) == .luteal
        }
        guard !lutealEntries.isEmpty else { return nil }

        let daysToPeriod = lutealEntries.compactMap {
            overlay.daysUntilNextPeriod(from: $0.timestamp)
        }
        guard !daysToPeriod.isEmpty, daysToPeriod.allSatisfy({ $0 <= 2 }) else { return nil }
        return "onset 1–2 days before bleeding"
    }

    private static func dominantLocation(
        from migraineEntries: [SymptomEntry],
        schema: SchemaConfig
    ) -> String? {
        let locations = migraineEntries.compactMap {
            PatternStatsEngine.primaryLocation(from: $0, schema: schema)
        }
        guard !locations.isEmpty else { return nil }
        let grouped = Dictionary(grouping: locations, by: { $0 }).mapValues(\.count)
        guard let top = grouped.max(by: { $0.value < $1.value }),
              top.value > migraineEntries.count / 2
        else { return nil }

        if top.key == "right side" || top.key == "left side" {
            let side = top.key.replacingOccurrences(of: " side", with: "")
            return "\(side)-sided"
        }
        return top.key
    }

    private static func auraPhraseForSummary(
        migraineEntries: [SymptomEntry],
        schema: SchemaConfig,
        hasAuraPreference: Bool
    ) -> String {
        for entry in migraineEntries {
            guard case .choices(let keys) = entry.fieldValues["aura"] else { continue }
            if keys.contains(where: { $0 != "none" }) {
                return "aura logged on some attacks"
            }
        }
        return hasAuraPreference ? "reports aura" : "no aura"
    }

    static func dateRangeLabel(from start: Date, to end: Date, calendar: Calendar) -> String {
        let monthFormatter = DateFormatter()
        monthFormatter.calendar = calendar
        monthFormatter.locale = Locale(identifier: "en_US_POSIX")
        monthFormatter.dateFormat = "MMM"

        let yearFormatter = DateFormatter()
        yearFormatter.calendar = calendar
        yearFormatter.locale = Locale(identifier: "en_US_POSIX")
        yearFormatter.dateFormat = "yyyy"

        let startMonth = monthFormatter.string(from: start).uppercased()
        let endMonth = monthFormatter.string(from: end).uppercased()
        let endYear = yearFormatter.string(from: end)

        if calendar.isDate(start, equalTo: end, toGranularity: .month) {
            return "\(startMonth) \(endYear)"
        }

        if calendar.isDate(start, equalTo: end, toGranularity: .year) {
            return "\(startMonth)–\(endMonth) \(endYear)"
        }

        let startYear = yearFormatter.string(from: start)
        return "\(startMonth) \(startYear)–\(endMonth) \(endYear)"
    }
}
