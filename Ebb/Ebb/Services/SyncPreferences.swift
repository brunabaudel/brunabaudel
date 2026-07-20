import Foundation
import Observation

/// User preference for iCloud backup — applied on the next app launch.
@Observable
final class SyncPreferences {
    static let iCloudSyncEnabledKey = "ebb.privacy.iCloudSyncEnabled"

    var iCloudSyncEnabled: Bool {
        get {
            if defaults.object(forKey: Self.iCloudSyncEnabledKey) == nil {
                return true
            }
            return defaults.bool(forKey: Self.iCloudSyncEnabledKey)
        }
        set { defaults.set(newValue, forKey: Self.iCloudSyncEnabledKey) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
}
