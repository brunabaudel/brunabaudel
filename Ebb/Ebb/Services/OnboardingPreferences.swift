import Foundation
import Observation

/// First-run onboarding completion flag (build-plan Phase 9).
@Observable
final class OnboardingPreferences {
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.completed) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if ProcessInfo.processInfo.hasLaunchArgumentSkipOnboarding {
            hasCompletedOnboarding = true
        } else {
            hasCompletedOnboarding = defaults.bool(forKey: Keys.completed)
        }
    }

    func markCompleted() {
        hasCompletedOnboarding = true
    }

    func resetForTesting() {
        hasCompletedOnboarding = false
    }

    // MARK: - Private

    private enum Keys {
        static let completed = "ebb.onboarding.completed"
    }

    private let defaults: UserDefaults
}
