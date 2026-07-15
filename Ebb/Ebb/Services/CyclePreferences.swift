import Foundation
import Observation

/// User-set cycle defaults used when HealthKit has no recent flow data.
@Observable
final class CyclePreferences {
    static let defaultCycleLength = 28
    static let defaultPeriodLength = 5
    static let cycleLengthRange = 21...45
    static let periodLengthRange = 2...10

    var typicalCycleLength: Int {
        didSet { persistCycleLength() }
    }

    var periodLength: Int {
        didSet { persistPeriodLength() }
    }

    /// Whether the user reports migraine aura — stored for doctor export (Phase 11),
    /// not used to gate logging.
    var hasAura: Bool {
        didSet { defaults.set(hasAura, forKey: Keys.hasAura) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedCycle = defaults.object(forKey: Keys.cycleLength) as? Int ?? Self.defaultCycleLength
        let storedPeriod = defaults.object(forKey: Keys.periodLength) as? Int ?? Self.defaultPeriodLength
        typicalCycleLength = Self.clampedCycleLength(storedCycle)
        periodLength = Self.clampedPeriodLength(storedPeriod)
        hasAura = defaults.bool(forKey: Keys.hasAura)
    }

    // MARK: - Private

    private enum Keys {
        static let cycleLength = "ebb.cycle.typicalLength"
        static let periodLength = "ebb.cycle.periodLength"
        static let hasAura = "ebb.cycle.hasAura"
    }

    private let defaults: UserDefaults

    private func persistCycleLength() {
        let clamped = Self.clampedCycleLength(typicalCycleLength)
        if typicalCycleLength != clamped {
            typicalCycleLength = clamped
            return
        }
        defaults.set(typicalCycleLength, forKey: Keys.cycleLength)
    }

    private func persistPeriodLength() {
        let clamped = Self.clampedPeriodLength(periodLength)
        if periodLength != clamped {
            periodLength = clamped
            return
        }
        defaults.set(periodLength, forKey: Keys.periodLength)
    }

    private static func clampedCycleLength(_ value: Int) -> Int {
        min(max(value, cycleLengthRange.lowerBound), cycleLengthRange.upperBound)
    }

    private static func clampedPeriodLength(_ value: Int) -> Int {
        min(max(value, periodLengthRange.lowerBound), periodLengthRange.upperBound)
    }
}
