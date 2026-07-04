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
}
