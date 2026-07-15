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
        didSet { persist() }
    }

    var periodLength: Int {
        didSet { persist() }
    }

    /// Whether the user reports migraine aura — stored for doctor export (Phase 11),
    /// not used to gate logging.
    var hasAura: Bool {
        didSet { persist() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        typicalCycleLength = defaults.object(forKey: Keys.cycleLength) as? Int ?? Self.defaultCycleLength
        periodLength = defaults.object(forKey: Keys.periodLength) as? Int ?? Self.defaultPeriodLength
        hasAura = defaults.bool(forKey: Keys.hasAura)
    }

    func clampedCycleLength(_ value: Int) -> Int {
        min(max(value, Self.cycleLengthRange.lowerBound), Self.cycleLengthRange.upperBound)
    }

    func clampedPeriodLength(_ value: Int) -> Int {
        min(max(value, Self.periodLengthRange.lowerBound), Self.periodLengthRange.upperBound)
    }

    // MARK: - Private

    private enum Keys {
        static let cycleLength = "ebb.cycle.typicalLength"
        static let periodLength = "ebb.cycle.periodLength"
        static let hasAura = "ebb.cycle.hasAura"
    }

    private let defaults: UserDefaults

    private func persist() {
        typicalCycleLength = clampedCycleLength(typicalCycleLength)
        periodLength = clampedPeriodLength(periodLength)
        defaults.set(typicalCycleLength, forKey: Keys.cycleLength)
        defaults.set(periodLength, forKey: Keys.periodLength)
        defaults.set(hasAura, forKey: Keys.hasAura)
    }
}
