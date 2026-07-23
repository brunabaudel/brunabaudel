import Foundation
import Testing
@testable import Ebb

@Suite("Doctor report engine")
struct DoctorReportEngineTests {
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
        severity: Int = 3,
        location: String = "right",
        triggers: [String] = [],
        relief: [String] = [],
        reliefEffect: String? = nil,
        cyclePhase: CyclePhase? = .luteal
    ) -> SymptomEntry {
        var values: [String: FieldValue] = [
            "migraine_present": .boolean(true),
            "severity": .scale(severity),
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

    @Test func emptyReportWhenNoMigraines() {
        let report = DoctorReportEngine.buildReport(
            entries: [],
            schema: schema,
            overlay: overlay(from: []),
            hasAuraPreference: false,
            typicalCycleLength: 28
        )

        #expect(!report.hasEnoughData)
        #expect(report.migraineCount == 0)
        #expect(report.summaryLine.contains("Log a migraine"))
    }

    @Test func lutealClusterSummaryAcrossMultipleCycles() {
        let periodStart = date(2026, 3, 1)
        let bleeding = SymptomEntry(
            timestamp: periodStart,
            schemaVersion: schema.schemaVersion,
            fieldValues: ["bleeding": .choice("medium")]
        )
        let entries = [
            bleeding,
            migraine(on: date(2026, 3, 17), severity: 4),
            migraine(on: date(2026, 3, 20), severity: 4),
            migraine(on: date(2026, 4, 18), severity: 3),
            migraine(on: date(2026, 4, 22), severity: 5),
        ]

        let report = DoctorReportEngine.buildReport(
            entries: entries,
            schema: schema,
            overlay: overlay(from: entries),
            hasAuraPreference: false,
            typicalCycleLength: 28,
            now: date(2026, 4, 25)
        )

        #expect(report.hasEnoughData)
        #expect(report.migraineCount == 4)
        #expect(report.cycleCount == 2)
        #expect(report.summaryLine.contains("luteal phase"))
        #expect(report.lutealPercentage == 100)
        #expect(report.dateRangeLabel.contains("MAR"))
        #expect(report.dateRangeLabel.contains("APR"))
    }

    @Test func triggersAndReliefLines() {
        let entries = [
            migraine(
                on: date(2026, 6, 10),
                triggers: ["poor_sleep", "stress"],
                relief: ["ibuprofen"],
                reliefEffect: "partial"
            ),
            migraine(
                on: date(2026, 6, 11),
                triggers: ["poor_sleep"],
                relief: ["naproxen"],
                reliefEffect: "partial"
            ),
        ]

        let report = DoctorReportEngine.buildReport(
            entries: entries,
            schema: schema,
            overlay: overlay(from: entries),
            hasAuraPreference: true,
            typicalCycleLength: 28
        )

        let triggers = DoctorReportEngine.triggersLine(from: report.topTriggers)
        #expect(triggers.contains("Poor sleep"))

        let relief = DoctorReportEngine.reliefLine(from: report.reliefSummaries)
        #expect(relief.contains("Ibuprofen"))
        #expect(relief.contains("partial"))
        #expect(report.auraSummary.contains("Reports aura"))
    }

    @Test func averageStatsFormatted() {
        let entries = [
            migraine(on: date(2026, 6, 10), severity: 4),
            migraine(on: date(2026, 6, 11), severity: 2),
        ]
        let report = DoctorReportEngine.buildReport(
            entries: entries,
            schema: schema,
            overlay: overlay(from: entries),
            hasAuraPreference: false,
            typicalCycleLength: 28
        )

        #expect(report.avgSeverity == 3)
        #expect(DoctorReportEngine.formattedAverage(report.avgSeverity) == "3")
        #expect(DoctorReportEngine.formattedAverage(3.2) == "3.2")
    }

    @Test func pdfDataGeneratedForValidReport() throws {
        let entries = [
            migraine(on: date(2026, 6, 10), severity: 4, triggers: ["stress"]),
        ]
        let report = DoctorReportEngine.buildReport(
            entries: entries,
            schema: schema,
            overlay: overlay(from: entries),
            hasAuraPreference: false,
            typicalCycleLength: 28
        )

        let data = try DoctorReportPDFRenderer.makePDFData(report: report)
        #expect(!data.isEmpty)
        #expect(String(data: data.prefix(4), encoding: .ascii) == "%PDF")
    }

    @Test func pdfExportFailsWithoutMigraines() {
        let report = DoctorReportEngine.buildReport(
            entries: [],
            schema: schema,
            overlay: overlay(from: []),
            hasAuraPreference: false,
            typicalCycleLength: 28
        )

        #expect(throws: DoctorReportPDFRenderer.Error.emptyReport) {
            try DoctorReportPDFRenderer.makePDFData(report: report)
        }
    }
}
