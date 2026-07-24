import Foundation
import Testing
@testable import Ebb

@Suite("DaySummaryBuilder")
struct DaySummaryBuilderTests {
    let schema = try! SchemaConfig.load(from: .main)
    let calendar = Calendar(identifier: .gregorian)
    let today = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 7, day: 4, hour: 14))!
    let yesterday = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 7, day: 3, hour: 10))!

    @Test func emptyTodayReturnsNothingLogged() {
        let entry = SymptomEntry(
            timestamp: yesterday,
            schemaVersion: schema.schemaVersion,
            fieldValues: ["migraine_present": .boolean(true)]
        )
        let summary = DaySummaryBuilder.todaySummary(
            entries: [entry],
            schema: schema,
            calendar: calendar,
            now: today
        )
        #expect(summary == "Nothing logged yet today.")
    }

    @Test func singleMigraineEntrySummary() {
        let entry = SymptomEntry(
            timestamp: today,
            schemaVersion: schema.schemaVersion,
            fieldValues: [
                "migraine_present": .boolean(true),
                "severity": .scale(3),
                "location": .choices(["right", "temple"]),
            ]
        )
        let summary = DaySummaryBuilder.todaySummary(
            entries: [entry],
            schema: schema,
            calendar: calendar,
            now: today
        )
        #expect(summary == "Migraine — moderate, right side and temple.")
    }

    @Test func multipleTodayEntriesMentionsCountAndLatest() {
        let older = SymptomEntry(
            timestamp: calendar.date(byAdding: .hour, value: -3, to: today)!,
            schemaVersion: schema.schemaVersion,
            fieldValues: ["bleeding": .choice("light")]
        )
        let newer = SymptomEntry(
            timestamp: today,
            schemaVersion: schema.schemaVersion,
            fieldValues: [
                "migraine_present": .boolean(true),
                "severity": .scale(2),
            ]
        )
        let summary = DaySummaryBuilder.todaySummary(
            entries: [newer, older],
            schema: schema,
            calendar: calendar,
            now: today
        )
        #expect(summary == "2 logs today. Latest: Migraine (mild)")
    }

    @Test func emptyFieldValuesFallback() {
        let entry = SymptomEntry(timestamp: today, schemaVersion: schema.schemaVersion)
        #expect(DaySummaryBuilder.describe(entry, schema: schema) == "Symptom log — no details filled in yet.")
    }

    @Test func periodAndCrampsPhrase() {
        let entry = SymptomEntry(
            timestamp: today,
            schemaVersion: schema.schemaVersion,
            fieldValues: [
                "migraine_present": .boolean(false),
                "bleeding": .choice("light"),
                "cramps_severity": .scale(2),
            ]
        )
        #expect(DaySummaryBuilder.describe(entry, schema: schema) == "No migraine. Light bleeding. mild cramps.")
    }

    @Test func todayRowMarkersMatchTimelineChips() {
        let migraine = SymptomEntry(
            timestamp: today,
            schemaVersion: schema.schemaVersion,
            fieldValues: [
                "migraine_present": .boolean(true),
                "severity": .scale(4),
                "location": .choices(["right"]),
                "associated_symptoms": .choices(["nausea"]),
                "relief_taken": .choices(["ibuprofen"]),
            ]
        )
        let migraineMarkers = DaySummaryBuilder.todayRowMarkers(migraine, schema: schema)
        #expect(DaySummaryBuilder.todayRowTitle(migraine, schema: schema) == "Migraine")
        #expect(migraineMarkers.map(\.label) == ["severe", "right side", "nausea", "ibuprofen"])
        #expect(migraineMarkers.map(\.kind) == [.pain, .pain, .pain, .neutral])

        let spotting = SymptomEntry(
            timestamp: today,
            schemaVersion: schema.schemaVersion,
            fieldValues: [
                "migraine_present": .boolean(false),
                "bleeding": .choice("spotting"),
                "cramps_severity": .scale(2),
            ],
            cyclePhase: .luteal
        )
        let spottingMarkers = DaySummaryBuilder.todayRowMarkers(spotting, schema: schema)
        #expect(spottingMarkers.map(\.label) == ["spotting", "mild cramps"])
        #expect(spottingMarkers.map(\.kind) == [.cycle, .cycle])

        let migraineInMenstrual = SymptomEntry(
            timestamp: today,
            schemaVersion: schema.schemaVersion,
            fieldValues: [
                "migraine_present": .boolean(true),
                "severity": .scale(3),
            ],
            cyclePhase: .menstrual
        )
        let migraineMarkersOnly = DaySummaryBuilder.todayRowMarkers(migraineInMenstrual, schema: schema)
        #expect(migraineMarkersOnly.map(\.label) == ["moderate"])
        #expect(!migraineMarkersOnly.contains(where: { $0.label == "menstrual" || $0.label == "luteal" }))
    }

    @Test func todayRowDescriptionMatchesTimelineCopy() {
        let migraine = SymptomEntry(
            timestamp: today,
            schemaVersion: schema.schemaVersion,
            fieldValues: [
                "migraine_present": .boolean(true),
                "severity": .scale(4),
                "location": .choices(["right"]),
                "quality": .choices(["throbbing"]),
                "relief_taken": .choices(["ibuprofen"]),
            ]
        )
        #expect(
            DaySummaryBuilder.todayRowDescription(migraine, schema: schema)
                == "Severe — right side and throbbing. Took ibuprofen."
        )

        let spotting = SymptomEntry(
            timestamp: today,
            schemaVersion: schema.schemaVersion,
            fieldValues: [
                "migraine_present": .boolean(false),
                "bleeding": .choice("spotting"),
                "cramps_severity": .scale(2),
            ],
            cyclePhase: .luteal
        )
        #expect(
            DaySummaryBuilder.todayRowDescription(spotting, schema: schema)
                == "Spotting, mild cramps."
        )

        let triggered = SymptomEntry(
            timestamp: today,
            schemaVersion: schema.schemaVersion,
            fieldValues: [
                "migraine_present": .boolean(true),
                "severity": .scale(3),
                "location": .choices(["right"]),
                "triggers": .choices(["stress"]),
            ]
        )
        #expect(
            DaySummaryBuilder.todayRowDescription(triggered, schema: schema)
                == "Moderate — right side. Possible trigger: stress."
        )
    }
}
