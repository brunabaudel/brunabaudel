import Foundation
import Testing
@testable import Ebb

@Suite("Pattern stats engine")
struct PatternStatsEngineTests {
    private let schema = try! SchemaConfig.load(from: .main)

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func overlay(from entries: [SymptomEntry]) -> CalendarCycleOverlay {
        CalendarCycleOverlay.build(from: entries, calendar: calendar)
    }

    private func migraine(
        on day: Date,
        location: String = "right",
        triggers: [String] = [],
        relief: [String] = [],
        reliefEffect: String? = nil,
        cyclePhase: CyclePhase? = .luteal
    ) -> SymptomEntry {
        var values: [String: FieldValue] = [
            "migraine_present": .boolean(true),
            "severity": .scale(3),
            "location": .choices([location]),
        ]
        if !triggers.isEmpty {
            values["triggers"] = .choices(triggers)
        }
        if !relief.isEmpty {
            values["relief_taken"] = .choices(relief)
            if let reliefEffect {
                values["relief_effect"] = .choice(reliefEffect)
            }
        }
        return SymptomEntry(
            timestamp: day,
            schemaVersion: schema.schemaVersion,
            fieldValues: values,
            cyclePhase: cyclePhase
        )
    }

    @Test func noCycleDataCaption() {
        let report = PatternStatsEngine.buildReport(
            entries: [],
            schema: schema,
            overlay: overlay(from: [])
        )
        #expect(!report.hasCycleData)
        #expect(report.timelineCaption.contains("HealthKit"))
    }

    @Test func lutealClusterCaptionForThreeMigraines() {
        let periodStart = date(2026, 6, 1)
        let bleeding = SymptomEntry(
            timestamp: periodStart,
            schemaVersion: schema.schemaVersion,
            fieldValues: ["bleeding": .choice("medium")]
        )
        let entries = [
            bleeding,
            migraine(on: date(2026, 6, 17)),
            migraine(on: date(2026, 6, 20)),
            migraine(on: date(2026, 6, 25)),
        ]
        let report = PatternStatsEngine.buildReport(
            entries: entries,
            schema: schema,
            overlay: overlay(from: entries),
            now: date(2026, 6, 26)
        )

        #expect(report.migraineCountThisCycle == 3)
        #expect(report.timelineCaption.contains("luteal phase"))
        #expect(report.timelineCaption.contains("3rd"))
        #expect(report.timeline.migraineCycleDays == [17, 20, 25])
    }

    @Test func rankedTriggersSortsByCount() {
        let entries = [
            migraine(on: date(2026, 6, 10), triggers: ["poor_sleep", "stress"]),
            migraine(on: date(2026, 6, 11), triggers: ["poor_sleep"]),
            migraine(on: date(2026, 6, 12), triggers: ["poor_sleep", "dehydration"]),
        ]
        let ranked = PatternStatsEngine.rankedTriggers(
            from: entries,
            schema: schema,
            limit: 4
        )
        #expect(ranked.map(\.key) == ["poor_sleep", "dehydration", "stress"])
        #expect(ranked[0].count == 3)
        #expect(ranked[0].fraction == 1)
        #expect(ranked[1].count == 1)
        #expect(ranked[1].fraction == 1.0 / 3.0)
    }

    @Test func sharedPoorSleepLutealInsight() {
        let periodStart = date(2026, 6, 1)
        let bleeding = SymptomEntry(
            timestamp: periodStart,
            schemaVersion: schema.schemaVersion,
            fieldValues: ["bleeding": .choice("medium")]
        )
        let entries = [
            bleeding,
            migraine(on: date(2026, 6, 17), triggers: ["poor_sleep"]),
            migraine(on: date(2026, 6, 20), triggers: ["poor_sleep"]),
            migraine(on: date(2026, 6, 24), triggers: ["poor_sleep"]),
        ]
        let builtOverlay = overlay(from: entries)
        let report = PatternStatsEngine.buildReport(
            entries: entries,
            schema: schema,
            overlay: builtOverlay,
            now: date(2026, 6, 26)
        )

        #expect(report.insight?.contains("poor sleep") == true)
        #expect(report.insight?.contains("luteal") == true)
    }

    @Test func dominantLocationInsight() {
        let periodStart = date(2026, 6, 1)
        let bleeding = SymptomEntry(
            timestamp: periodStart,
            schemaVersion: schema.schemaVersion,
            fieldValues: ["bleeding": .choice("medium")]
        )
        let entries = [
            bleeding,
            migraine(on: date(2026, 6, 17), location: "right"),
            migraine(on: date(2026, 6, 20), location: "right"),
        ]
        let report = PatternStatsEngine.buildReport(
            entries: entries,
            schema: schema,
            overlay: overlay(from: entries),
            now: date(2026, 6, 21)
        )

        #expect(report.insight?.contains("right side") == true)
        #expect(report.insight?.contains("luteal") == true)
    }

    @Test func reliefEffectivenessCountsHelpful() {
        let entries = [
            migraine(on: date(2026, 6, 10), relief: ["ibuprofen"], reliefEffect: "partial"),
            migraine(on: date(2026, 6, 11), relief: ["ibuprofen"], reliefEffect: "none"),
            migraine(on: date(2026, 6, 12), relief: ["triptan"], reliefEffect: "full"),
        ]
        let stats = PatternStatsEngine.reliefStats(from: entries, schema: schema)
        let ibuprofen = stats.first { $0.key == "ibuprofen" }
        let triptan = stats.first { $0.key == "triptan" }

        #expect(ibuprofen?.timesTaken == 2)
        #expect(ibuprofen?.timesHelpful == 1)
        #expect(triptan?.timesHelpful == 1)
    }

    @Test func entriesInCycleFiltersToCurrentPeriod() {
        let periodStart = date(2026, 6, 1)
        let bleeding = SymptomEntry(
            timestamp: periodStart,
            schemaVersion: schema.schemaVersion,
            fieldValues: ["bleeding": .choice("medium")]
        )
        let current = migraine(on: date(2026, 6, 20))
        let previousCycle = migraine(on: date(2026, 5, 20))
        let entries = [bleeding, current, previousCycle]
        let builtOverlay = overlay(from: entries)

        let inCycle = builtOverlay.entriesInCycle(containing: date(2026, 6, 21), from: entries)
        #expect(inCycle.count == 2)
        #expect(!inCycle.contains { $0.timestamp == previousCycle.timestamp })
    }

    @Test func cycleTimelinePhaseSegments() {
        let timeline = PatternStatsEngine.CycleTimeline(
            cycleLength: 28,
            periodLength: 5,
            migraineCycleDays: [17],
            lutealStartFraction: 0.52,
            lutealEndFraction: 1
        )
        #expect(timeline.menstrualDayCount == 5)
        #expect(timeline.follicularDayCount == 9)
        #expect(timeline.lutealDayCount == 14)
        #expect(timeline.menstrualDayCount + timeline.follicularDayCount + timeline.lutealDayCount == 28)
    }

    @Test func lutealTimelineRange() {
        let overlay = CalendarCycleOverlay(calendar: calendar, cycleLength: 28, periodLength: 5)
        let range = overlay.lutealTimelineRange()
        #expect(range.start > 0.45)
        #expect(range.end == 1)
    }

    @Test func ordinalPhrase() {
        #expect(PatternStatsEngine.ordinalPhrase(1) == "1st")
        #expect(PatternStatsEngine.ordinalPhrase(2) == "2nd")
        #expect(PatternStatsEngine.ordinalPhrase(3) == "3rd")
        #expect(PatternStatsEngine.ordinalPhrase(4) == "4th")
    }
}
