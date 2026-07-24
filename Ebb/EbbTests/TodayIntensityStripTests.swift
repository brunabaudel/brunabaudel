import Foundation
import Testing
@testable import Ebb

@Suite("TodayIntensityStrip")
struct TodayIntensityStripTests {
    let schema = try! SchemaConfig.load(from: .main)
    let calendar = Calendar(identifier: .gregorian)
    let day = Calendar(identifier: .gregorian).date(
        from: DateComponents(year: 2026, month: 7, day: 24, hour: 12)
    )!

    @Test func entriesFilterToSelectedBlock() {
        let overnight = entry(hour: 2, minute: 30)
        let morning = entry(hour: 8, minute: 0)
        let afternoon = entry(hour: 14, minute: 15)
        let evening = entry(hour: 21, minute: 8)

        // 2:30 falls in block 0 (12a–3a)
        let overnightMatches = TodayIntensityStrip.entries(
            [overnight, morning, afternoon, evening],
            inBlock: 0,
            day: day,
            calendar: calendar
        )
        #expect(overnightMatches.map(\.id) == [overnight.id])

        // 14:15 falls in block 4 (12p–3p)
        let afternoonMatches = TodayIntensityStrip.entries(
            [overnight, morning, afternoon, evening],
            inBlock: 4,
            day: day,
            calendar: calendar
        )
        #expect(afternoonMatches.map(\.id) == [afternoon.id])

        // 21:08 falls in block 7 (9p–12a)
        let eveningMatches = TodayIntensityStrip.entries(
            [overnight, morning, afternoon, evening],
            inBlock: 7,
            day: day,
            calendar: calendar
        )
        #expect(eveningMatches.map(\.id) == [evening.id])
    }

    @Test func emptyBlockReturnsNoEntries() {
        let evening = entry(hour: 21, minute: 8)
        let matches = TodayIntensityStrip.entries(
            [evening],
            inBlock: 0,
            day: day,
            calendar: calendar
        )
        #expect(matches.isEmpty)
    }

    @Test func blockIndexMatchesCurrentTime() {
        let afternoon = calendar.date(bySettingHour: 14, minute: 15, second: 0, of: day)!
        #expect(TodayIntensityStrip.blockIndex(containing: afternoon, day: day, calendar: calendar) == 4)

        let overnight = calendar.date(bySettingHour: 2, minute: 30, second: 0, of: day)!
        #expect(TodayIntensityStrip.blockIndex(containing: overnight, day: day, calendar: calendar) == 0)
    }

    @Test func blockDateRangesAreThreeHoursAcrossFullDay() {
        guard let first = TodayIntensityStrip.blockDateRange(index: 0, day: day, calendar: calendar),
              let last = TodayIntensityStrip.blockDateRange(
                index: TodayIntensityStrip.blockCount - 1,
                day: day,
                calendar: calendar
              ) else {
            Issue.record("Expected block ranges")
            return
        }

        #expect(TodayIntensityStrip.blockCount == 8)
        #expect(calendar.component(.hour, from: first.lowerBound) == 0)
        #expect(calendar.component(.minute, from: first.lowerBound) == 0)
        #expect(first.upperBound.timeIntervalSince(first.lowerBound) == 3 * 60 * 60)
        #expect(calendar.component(.hour, from: last.upperBound) == 0)
        #expect(calendar.component(.minute, from: last.upperBound) == 0)
        #expect(calendar.isDate(last.upperBound, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: day)!))

        for index in 0..<(TodayIntensityStrip.blockCount - 1) {
            let current = TodayIntensityStrip.blockDateRange(index: index, day: day, calendar: calendar)
            let next = TodayIntensityStrip.blockDateRange(index: index + 1, day: day, calendar: calendar)
            #expect(current?.upperBound == next?.lowerBound)
        }
    }

    private func entry(hour: Int, minute: Int) -> SymptomEntry {
        let timestamp = calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: day
        )!
        return SymptomEntry(
            timestamp: timestamp,
            schemaVersion: schema.schemaVersion,
            fieldValues: [
                "migraine_present": .boolean(true),
                "severity": .scale(3),
            ]
        )
    }
}
