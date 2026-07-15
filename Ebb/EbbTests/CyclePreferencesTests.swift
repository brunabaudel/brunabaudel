import Foundation
import Testing
@testable import Ebb

@Suite("Cycle preferences")
struct CyclePreferencesTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "ebb.cycle.preferences.tests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    @Test func togglingAuraDoesNotRecurse() {
        let defaults = makeDefaults()
        let preferences = CyclePreferences(defaults: defaults)
        preferences.hasAura = true
        preferences.hasAura = false
        #expect(defaults.bool(forKey: "ebb.cycle.hasAura") == false)
    }

    @Test func stepperClampsCycleLength() {
        let defaults = makeDefaults()
        let preferences = CyclePreferences(defaults: defaults)
        preferences.typicalCycleLength = 99
        #expect(preferences.typicalCycleLength == 45)
        #expect(defaults.integer(forKey: "ebb.cycle.typicalLength") == 45)
    }

    @Test func stepperClampsPeriodLength() {
        let defaults = makeDefaults()
        let preferences = CyclePreferences(defaults: defaults)
        preferences.periodLength = 1
        #expect(preferences.periodLength == 2)
        #expect(defaults.integer(forKey: "ebb.cycle.periodLength") == 2)
    }
}
