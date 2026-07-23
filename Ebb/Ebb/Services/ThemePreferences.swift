import Foundation
import Observation

/// Persists the user's theme choice. Non-default themes require Ebb+.
@Observable
final class ThemePreferences {
    var selectedThemeID: String {
        didSet { defaults.set(selectedThemeID, forKey: Keys.selectedThemeID) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selectedThemeID = defaults.string(forKey: Keys.selectedThemeID) ?? Theme.plumEmber.id
    }

    func effectiveTheme(isEbbPlus: Bool) -> Theme {
        let selected = Theme.theme(for: selectedThemeID) ?? .plumEmber
        if selected.isFreeDefault || isEbbPlus {
            return selected
        }
        return .plumEmber
    }

    func canUse(_ theme: Theme, isEbbPlus: Bool) -> Bool {
        theme.isFreeDefault || isEbbPlus
    }

    func select(_ theme: Theme, isEbbPlus: Bool) -> Bool {
        guard canUse(theme, isEbbPlus: isEbbPlus) else { return false }
        selectedThemeID = theme.id
        return true
    }

    // MARK: - Private

    private enum Keys {
        static let selectedThemeID = "ebb.appearance.selectedThemeID"
    }

    private let defaults: UserDefaults
}
