import Foundation
import LocalAuthentication
import Observation
import SwiftUI

/// Face ID / passcode gate for the migraine log (build-plan Phase 8).
@Observable
@MainActor
final class AppLockController {
    private(set) var isLocked = false
    private(set) var lastErrorMessage: String?

    var isEnabled: Bool {
        get { defaults.bool(forKey: Keys.enabled) }
        set {
            defaults.set(newValue, forKey: Keys.enabled)
            if newValue {
                lock()
            } else {
                unlock()
            }
        }
    }

    var lockMethodLabel: String {
        isEnabled ? Self.biometryLabel() : "Off"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if isEnabled {
            isLocked = true
        }
    }

    func lock() {
        guard isEnabled else { return }
        isLocked = true
    }

    func unlock() {
        isLocked = false
        lastErrorMessage = nil
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            lock()
        case .active where isEnabled && isLocked:
            Task { await authenticate(reason: "Unlock Ebb") }
        default:
            break
        }
    }

    /// Enables app lock after a successful local authentication check.
    func enableAfterAuthentication() async -> Bool {
        let success = await authenticate(reason: "Turn on app lock", requiresEnabled: false)
        if success {
            defaults.set(true, forKey: Keys.enabled)
            unlock()
        }
        return success
    }

    @discardableResult
    func authenticate(reason: String, requiresEnabled: Bool = true) async -> Bool {
        if requiresEnabled && !isEnabled {
            unlock()
            return true
        }

        lastErrorMessage = nil
        let context = LAContext()
        var authError: NSError?
        let policy: LAPolicy = .deviceOwnerAuthentication

        guard context.canEvaluatePolicy(policy, error: &authError) else {
            lastErrorMessage = authError?.localizedDescription ?? "App lock is not available on this device."
            return false
        }

        do {
            let success = try await context.evaluatePolicy(policy, localizedReason: reason)
            if success {
                unlock()
            }
            return success
        } catch let error as LAError where error.code == .userCancel || error.code == .systemCancel {
            return false
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    private static func biometryLabel() -> String {
        switch LAContext().biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    private enum Keys {
        static let enabled = "ebb.privacy.appLockEnabled"
    }
}
