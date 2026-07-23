import Observation
import SwiftUI

/// Permission sequencing for first-run onboarding (build-plan Phase 9).
@Observable
@MainActor
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case welcome
        case cycleInfo
        case healthKit
        case microphone
        case notifications
    }

    private(set) var step: Step = .welcome
    private(set) var isRequestingPermission = false

    func advance(from preferences: OnboardingPreferences) {
        guard let next = Step(rawValue: step.rawValue + 1) else {
            preferences.markCompleted()
            return
        }
        step = next
    }

    func skipToEnd(from preferences: OnboardingPreferences) {
        preferences.markCompleted()
    }

    func requestHealthKit(cycleService: CycleService, appLock: AppLockController) async {
        isRequestingPermission = true
        appLock.beginHealthKitAuthorizationFlow()
        defer {
            isRequestingPermission = false
            appLock.endPermissionFlow()
        }
        await cycleService.requestAuthorization()
    }

    func requestMicrophone(speechCapture: SpeechCapture) async {
        isRequestingPermission = true
        defer { isRequestingPermission = false }
        await speechCapture.requestAuthorization()
        speechCapture.refreshAuthorizationStatus()
    }

    func requestNotifications() async {
        isRequestingPermission = true
        defer { isRequestingPermission = false }
        _ = await ReminderScheduler.requestAuthorization()
    }
}
