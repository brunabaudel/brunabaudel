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
        isEnabled ? cachedBiometryLabel : "Off"
    }

    private let defaults: UserDefaults
    private var cachedBiometryLabel = "Face ID"
    private var hasBeenBackgrounded = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        cachedBiometryLabel = Self.resolveBiometryLabel()

        guard isEnabled else { return }

        guard Self.canEvaluateAppLock() else {
            // Avoid bricking the app when biometrics/passcode are unavailable.
            defaults.set(false, forKey: Keys.enabled)
            return
        }

        isLocked = true
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
            }
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    /// Enables app lock after a successful local authentication check.
    func enableAfterAuthentication() async -> Bool {
        guard Self.canEvaluateAppLock() else {
            lastErrorMessage = "App lock is not available on this device."
            return false
        }

        let success = await authenticate(reason: "Turn on app lock", requiresEnabled: false)
        if success {
            defaults.set(true, forKey: Keys.enabled)
            cachedBiometryLabel = Self.resolveBiometryLabel()
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

        guard Self.canEvaluateAppLock() else {
            lastErrorMessage = "App lock is not available on this device."
            if requiresEnabled {
                defaults.set(false, forKey: Keys.enabled)
                unlock()
            }
            return false
        }

        let context = LAContext()
        context.localizedFallbackTitle = "Enter Passcode"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
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

    static func isBiometricLockAvailable() -> Bool {
        canEvaluateAppLock()
    }

    private static func canEvaluateAppLock() -> Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    private static func resolveBiometryLabel() -> String {
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

/// Hosts app-lock scene handling inside the window — not on `App` itself.
struct AppLockGate<Content: View>: View {
    @Environment(AppLockController.self) private var appLock
    @Environment(\.scenePhase) private var scenePhase
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            content()

            if appLock.isLocked && !AppRuntime.isRunningTests {
                AppLockOverlay()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appLock.isLocked)
        .onChange(of: scenePhase) { _, newPhase in
            appLock.handleScenePhase(newPhase)
        }
    }
}
