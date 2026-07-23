import Foundation

/// Deterministic pattern synthesis for the Patterns screen (build-plan Phase 7).
/// Pure Swift — no model calls. Phrasing is template-driven from computed stats.
enum PatternStatsEngine {
    // MARK: - Public types

    struct Report: Equatable, Sendable {
        let hasCycleData: Bool
        let migraineCountThisCycle: Int
        let timelineCaption: String
        let timeline: CycleTimeline
        let topTriggers: [RankedCount]
        let reliefEffectiveness: [ReliefStat]
        let insight: String?
    }

    struct CycleTimeline: Equatable, Sendable {
        let cycleLength: Int
        let periodLength: Int
        /// Cycle days (1-based) with a logged migraine in the current cycle.
        let migraineCycleDays: [Int]
        let lutealStartFraction: Double
        let lutealEndFraction: Double

        /// Days 1…periodLength — matches `CalendarCycleOverlay.phase`.
        var menstrualDayCount: Int { max(periodLength, 1) }

        /// Days after bleeding through ovulation (day 14).
        var follicularDayCount: Int { max(14 - periodLength, 1) }

        /// Days 15…cycleLength.
        var lutealDayCount: Int { max(cycleLength - 14, 1) }
    }

    struct RankedCount: Equatable, Sendable {
        let key: String
        let label: String
        let count: Int
        /// Relative bar width, 0…1, compared to the top item.
        let fraction: Double
    }

    struct ReliefStat: Equatable, Sendable {
        let key: String
        let label: String
        let timesTaken: Int
        let timesHelpful: Int
        let helpfulFraction: Double
    }

    // MARK: - Build

    static func buildReport(
        entries: [SymptomEntry],
        schema: SchemaConfig,
        overlay: CalendarCycleOverlay,
        now: Date = .now
    ) -> Report {
        let hasCycleData = overlay.anchorPeriodStart != nil
        let cycleEntries = overlay.entriesInCycle(containing: now, from: entries)
        let migraineEntries = cycleEntries.filter(isMigraine)
        let lutealRange = overlay.lutealTimelineRange()

        let migraineDays = migraineEntries.compactMap { overlay.cycleDay(for: $0.timestamp) }
        let timeline = CycleTimeline(
            cycleLength: overlay.cycleLength,
            periodLength: overlay.periodLength,
            migraineCycleDays: Array(Set(migraineDays)).sorted(),
            lutealStartFraction: lutealRange.start,
            lutealEndFraction: lutealRange.end
        )

        let topTriggers = rankedTriggers(
            from: migraineEntries,
            schema: schema,
            limit: 4
        )
        let reliefEffectiveness = reliefStats(from: migraineEntries, schema: schema)

        let timelineCaption = timelineCaption(
            migraineEntries: migraineEntries,
            overlay: overlay,
            hasCycleData: hasCycleData
        )
        let insight = insightPhrase(
            migraineEntries: migraineEntries,
            topTriggers: topTriggers,
            overlay: overlay,
            schema: schema,
            hasCycleData: hasCycleData
        )

        return Report(
            hasCycleData: hasCycleData,
            migraineCountThisCycle: migraineEntries.count,
            timelineCaption: timelineCaption,
            timeline: timeline,
            topTriggers: topTriggers,
            reliefEffectiveness: reliefEffectiveness,
            insight: insight
        )
    }

    // MARK: - Timeline caption

    static func timelineCaption(
        migraineEntries: [SymptomEntry],
        overlay: CalendarCycleOverlay,
        hasCycleData: Bool
    ) -> String {
        guard hasCycleData else {
            return "Log bleeding or connect HealthKit to see how migraines track with your cycle."
        }

        let count = migraineEntries.count
        guard count > 0 else {
            return "No migraines logged this cycle yet. Patterns will appear as you log."
        }

        let phases = migraineEntries.compactMap { resolvedPhase(for: $0, overlay: overlay) }
        let phaseCounts = Dictionary(grouping: phases, by: { $0 }).mapValues(\.count)
        let dominantPhase = phaseCounts.max(by: { $0.value < $1.value })?.key

        if count == 1, let phase = dominantPhase {
            return singleMigraineCaption(
                phase: phase,
                entry: migraineEntries[0],
                overlay: overlay
            )
        }

        if let dominantPhase, phaseCounts.count == 1 {
            return clusterCaption(count: count, phase: dominantPhase)
        }

        if let dominantPhase, let dominantCount = phaseCounts[dominantPhase], dominantCount > count / 2 {
            return "You've logged \(count) migraines this cycle, mostly in the \(dominantPhase.displayName.lowercased()) phase."
        }

        return "You've logged \(count) migraines this cycle across \(phaseCounts.count) cycle phases."
    }

    private static func singleMigraineCaption(
        phase: CyclePhase,
        entry: SymptomEntry,
        overlay: CalendarCycleOverlay
    ) -> String {
        if phase == .luteal {
            return "Your migraine landed in the luteal phase — the days estrogen drops before your period."
        }
        if let day = overlay.cycleDay(for: entry.timestamp) {
            return "One migraine logged this cycle on cycle day \(day) (\(phase.displayName.lowercased()) phase)."
        }
        return "One migraine logged this cycle during the \(phase.displayName.lowercased()) phase."
    }

    private static func clusterCaption(count: Int, phase: CyclePhase) -> String {
        let tally = count == 2 ? "Both" : ordinalPhrase(count)
        switch phase {
        case .luteal:
            return "Your migraines cluster in the luteal phase — the days estrogen drops before your period. \(tally) this cycle, all luteal."
        case .menstrual:
            return "Your migraines cluster during bleeding — \(tally) this cycle, all menstrual."
        case .follicular:
            return "Your migraines cluster in the follicular phase — \(tally) this cycle."
        case .ovulation:
            return "Your migraines cluster around ovulation — \(tally) this cycle."
        }
    }

    // MARK: - Insight

    static func insightPhrase(
        migraineEntries: [SymptomEntry],
        topTriggers: [RankedCount],
        overlay: CalendarCycleOverlay,
        schema: SchemaConfig,
        hasCycleData: Bool
    ) -> String? {
        guard hasCycleData, migraineEntries.count >= 2 else { return nil }

        if let triggerInsight = sharedTriggerInsight(
            migraineEntries: migraineEntries,
            topTriggers: topTriggers,
            overlay: overlay
        ) {
            return triggerInsight
        }

        if let locationInsight = dominantLocationInsight(
            migraineEntries: migraineEntries,
            overlay: overlay,
            schema: schema
        ) {
            return locationInsight
        }

        if let reliefInsight = reliefInsight(
            from: migraineEntries,
            schema: schema
        ) {
            return reliefInsight
        }

        return nil
    }

    private static func sharedTriggerInsight(
        migraineEntries: [SymptomEntry],
        topTriggers: [RankedCount],
        overlay: CalendarCycleOverlay
    ) -> String? {
        guard let top = topTriggers.first, top.count >= 2 else { return nil }

        let lutealMigraines = migraineEntries.filter {
            resolvedPhase(for: $0, overlay: overlay) == .luteal
        }
        guard lutealMigraines.count >= 2 else { return nil }

        let withTrigger = lutealMigraines.filter { triggers(from: $0).contains(top.key) }
        guard withTrigger.count == lutealMigraines.count else { return nil }

        let attackWord = lutealMigraines.count == 1 ? "attack" : "attacks"
        return "All \(lutealMigraines.count) \(attackWord) followed \(top.label.lowercased()) in the luteal window."
    }

    private static func dominantLocationInsight(
        migraineEntries: [SymptomEntry],
        overlay: CalendarCycleOverlay,
        schema: SchemaConfig
    ) -> String? {
        guard migraineEntries.count >= 2 else { return nil }

        let locations = migraineEntries.compactMap { primaryLocation(from: $0, schema: schema) }
        guard locations.count == migraineEntries.count else { return nil }

        let grouped = Dictionary(grouping: locations, by: { $0 })
        guard grouped.count == 1, let location = locations.first else { return nil }

        let phases = Set(migraineEntries.compactMap { resolvedPhase(for: $0, overlay: overlay) })
        guard phases.count == 1, let phase = phases.first else { return nil }

        let ordinal = ordinalPhrase(migraineEntries.count)
        return "\(ordinal.capitalized) \(location) migraine this cycle, all \(phase.displayName.lowercased())."
    }

    private static func reliefInsight(
        from migraineEntries: [SymptomEntry],
        schema: SchemaConfig
    ) -> String? {
        let withRelief = migraineEntries.filter { !reliefKeys(from: $0).isEmpty }
        guard withRelief.count >= 2 else { return nil }

        let helpful = withRelief.filter { isHelpfulRelief($0) }
        guard helpful.isEmpty else { return nil }

        return "Relief logged \(withRelief.count) times this cycle without much help — worth noting for your doctor."
    }

    // MARK: - Rankings

    static func rankedTriggers(
        from migraineEntries: [SymptomEntry],
        schema: SchemaConfig,
        limit: Int
    ) -> [RankedCount] {
        var counts: [String: Int] = [:]
        for entry in migraineEntries {
            for key in triggers(from: entry) {
                counts[key, default: 0] += 1
            }
        }

        let sorted = counts.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key < rhs.key
        }
        let maxCount = sorted.first?.value ?? 0
        guard maxCount > 0 else { return [] }

        return sorted.prefix(limit).map { key, count in
            RankedCount(
                key: key,
                label: schema.field(forKey: "triggers")?.values.first { $0.key == key }?.label ?? key,
                count: count,
                fraction: Double(count) / Double(maxCount)
            )
        }
    }

    static func reliefStats(
        from migraineEntries: [SymptomEntry],
        schema: SchemaConfig
    ) -> [ReliefStat] {
        var taken: [String: Int] = [:]
        var helpful: [String: Int] = [:]

        for entry in migraineEntries {
            let keys = reliefKeys(from: entry)
            guard !keys.isEmpty else { continue }
            let helped = isHelpfulRelief(entry)
            for key in keys {
                taken[key, default: 0] += 1
                if helped { helpful[key, default: 0] += 1 }
            }
        }

        let field = schema.field(forKey: "relief_taken")
        return taken.sorted { $0.value > $1.value }.map { key, count in
            let helpCount = helpful[key] ?? 0
            return ReliefStat(
                key: key,
                label: field?.values.first { $0.key == key }?.label ?? key,
                timesTaken: count,
                timesHelpful: helpCount,
                helpfulFraction: count > 0 ? Double(helpCount) / Double(count) : 0
            )
        }
    }

    // MARK: - Entry helpers

    static func isMigraine(_ entry: SymptomEntry) -> Bool {
        entry.fieldValues["migraine_present"] == .boolean(true)
    }

    static func resolvedPhase(for entry: SymptomEntry, overlay: CalendarCycleOverlay) -> CyclePhase? {
        if let stamped = entry.cyclePhase { return stamped }
        return overlay.phase(for: entry.timestamp)
    }

    static func triggers(from entry: SymptomEntry) -> [String] {
        guard case .choices(let keys) = entry.fieldValues["triggers"] else { return [] }
        return keys
    }

    static func reliefKeys(from entry: SymptomEntry) -> [String] {
        guard case .choices(let keys) = entry.fieldValues["relief_taken"] else { return [] }
        return keys
    }

    static func isHelpfulRelief(_ entry: SymptomEntry) -> Bool {
        guard case .choice(let effect) = entry.fieldValues["relief_effect"] else { return false }
        return effect == "partial" || effect == "full"
    }

    static func primaryLocation(from entry: SymptomEntry, schema: SchemaConfig) -> String? {
        guard case .choices(let keys) = entry.fieldValues["location"], let first = keys.first else {
            return nil
        }
        return schema.field(forKey: "location")?.values.first { $0.key == first }?.label.lowercased()
    }

    static func ordinalPhrase(_ count: Int) -> String {
        switch count {
        case 1: "1st"
        case 2: "2nd"
        case 3: "3rd"
        default: "\(count)th"
        }
    }
}
