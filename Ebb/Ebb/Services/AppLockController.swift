import Foundation
import LocalAuthentication
import Observation
import SwiftUI

/// Face ID / passcode gate for the migraine log (build-plan Phase 8).
@Observable
@MainActor
final class AppLockController {
    /// Why app lock is temporarily suppressed (HealthKit sheet or Health app).
    enum PermissionFlowKind: Equatable {
        case healthKitAuthorization
        case externalHealthApp
    }

    private(set) var isLocked = false
    private(set) var lastErrorMessage: String?
    private(set) var activePermissionFlow: PermissionFlowKind?
    private(set) var isAuthenticating = false

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
    private var hasBeenBackgrounded = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if isEnabled {
            isLocked = true
        }
    }

    var isPermissionFlowActive: Bool {
        activePermissionFlow != nil
    }

    /// While the HealthKit permission sheet is visible.
    func beginHealthKitAuthorizationFlow() {
        activePermissionFlow = .healthKitAuthorization
    }

    /// While the user is in the Health app following in-app instructions.
    func beginExternalHealthAppFlow() {
        activePermissionFlow = .externalHealthApp
    }

    func endPermissionFlow() {
        activePermissionFlow = nil
    }

    func lock() {
        guard isEnabled, activePermissionFlow == nil else { return }
        isLocked = true
    }

    func unlock() {
        isLocked = false
        lastErrorMessage = nil
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            hasBeenBackgrounded = true
            lock()
        case .active:
            if activePermissionFlow == .externalHealthApp {
                endPermissionFlow()
                return
            }
            promptUnlockIfNeeded(whenReturningFromBackground: true)
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

        guard !isAuthenticating else { return false }

        lastErrorMessage = nil
        isAuthenticating = true
        defer { isAuthenticating = false }

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

    // MARK: - Private

    private func promptUnlockIfNeeded(whenReturningFromBackground: Bool) {
        guard isEnabled, isLocked, !isAuthenticating else { return }
        if whenReturningFromBackground {
            guard hasBeenBackgrounded else { return }
        }

        Task {
            // Let the window finish presenting before showing Face ID.
            try? await Task.sleep(for: .milliseconds(350))
            guard isEnabled, isLocked, !isAuthenticating else { return }
            await authenticate(reason: "Unlock Ebb")
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
