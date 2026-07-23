import Foundation
import Observation

/// Relief options the user takes regularly — pre-fill Confirm (build-plan Phase 9).
@Observable
final class MedicationPreferences {
    var savedReliefKeys: [String] {
        didSet { persist() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        savedReliefKeys = defaults.stringArray(forKey: Keys.savedReliefKeys) ?? []
    }

    func isSaved(_ key: String) -> Bool {
        savedReliefKeys.contains(key)
    }

    func setSaved(_ key: String, isSaved: Bool) {
        if isSaved {
            guard !savedReliefKeys.contains(key) else { return }
            savedReliefKeys.append(key)
        } else {
            savedReliefKeys.removeAll { $0 == key }
        }
    }

    func resetToDefaults() {
        savedReliefKeys = []
    }

    // MARK: - Private

    private enum Keys {
        static let savedReliefKeys = "ebb.medications.savedReliefKeys"
    }

    private let defaults: UserDefaults

    private func persist() {
        defaults.set(savedReliefKeys, forKey: Keys.savedReliefKeys)
    }
}
