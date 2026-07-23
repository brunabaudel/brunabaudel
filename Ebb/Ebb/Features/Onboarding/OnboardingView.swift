import SwiftUI

/// First-run flow: disclaimer, cycle info, and in-context permissions (Phase 9).
struct OnboardingView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Bindable var onboardingPreferences: OnboardingPreferences

    @Environment(\.theme) private var theme
    @Environment(CycleService.self) private var cycleService
    @Environment(SpeechCapture.self) private var speechCapture
    @Environment(AppLockController.self) private var appLock

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.step {
                case .welcome:
                    welcomeStep
                case .cycleInfo:
                    cycleInfoStep
                case .healthKit:
                    healthKitStep
                case .microphone:
                    microphoneStep
                case .notifications:
                    notificationsStep
                }
            }
            .background(theme.base)
            .foregroundStyle(theme.text)
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("A calmer way to track ")
                        .font(.system(.title2, design: .serif))
                    + Text("migraines")
                        .font(.system(.title2, design: .serif))
                        .foregroundColor(theme.pain)
                    + Text(" and your cycle.")
                        .font(.system(.title2, design: .serif))
                    Text("Everything stays on your phone. Talk or tap — your choice, every time.")
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)
                }
                .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 12) {
                    permissionCard(
                        icon: "heart.text.square.fill",
                        title: "Apple Health",
                        detail: "Reads your cycle dates so migraines line up with your hormones — no double entry."
                    )
                    permissionCard(
                        icon: "mic.fill",
                        title: "Microphone",
                        detail: "So you can say how you feel and let the app fill the chart. Recognition stays on this device."
                    )
                    permissionCard(
                        icon: "bell.fill",
                        title: "Notifications",
                        detail: "A gentle nudge entering your higher-risk luteal days. Optional."
                    )
                }

                disclaimerRow

                primaryButton("Get started") {
                    viewModel.advance(from: onboardingPreferences)
                }
            }
            .padding(24)
        }
    }

    // MARK: - Cycle info

    private var cycleInfoStep: some View {
        @Bindable var preferences = cycleService.preferences

        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                stepHeader(
                    title: "Your cycle",
                    subtitle: "Optional — helps when HealthKit has no recent flow data."
                )

                Stepper(
                    value: $preferences.typicalCycleLength,
                    in: CyclePreferences.cycleLengthRange,
                    step: 1
                ) {
                    LabeledContent("Typical cycle length") {
                        Text("\(preferences.typicalCycleLength) days")
                    }
                }
                .padding(16)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(theme.line, lineWidth: 1)
                }

                Toggle(isOn: $preferences.hasAura) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("I get migraine aura")
                        Text("Visual or sensory warning before a migraine. Recorded for your doctor export — Ebb never gives medical advice.")
                            .font(.caption)
                            .foregroundStyle(theme.muted)
                    }
                }
                .padding(16)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(theme.line, lineWidth: 1)
                }

                HStack(spacing: 12) {
                    secondaryButton("Skip") {
                        viewModel.advance(from: onboardingPreferences)
                    }
                    primaryButton("Continue") {
                        viewModel.advance(from: onboardingPreferences)
                    }
                }
            }
            .padding(24)
        }
    }

    // MARK: - HealthKit

    private var healthKitStep: some View {
        permissionStep(
            icon: "heart.text.square.fill",
            title: "Connect Apple Health",
            detail: "Ebb reads menstrual flow to tag your cycle phase and predict your next period. Nothing is written to HealthKit.",
            primaryTitle: viewModel.isRequestingPermission ? "Connecting…" : "Connect Health",
            primaryAction: {
                Task {
                    await viewModel.requestHealthKit(cycleService: cycleService, appLock: appLock)
                    viewModel.advance(from: onboardingPreferences)
                }
            },
            skipAction: { viewModel.advance(from: onboardingPreferences) }
        )
    }

    // MARK: - Microphone

    private var microphoneStep: some View {
        permissionStep(
            icon: "mic.fill",
            title: "Allow the microphone",
            detail: "So you can say how you feel during an attack. Speech stays on this device — nothing is sent to a server.",
            primaryTitle: viewModel.isRequestingPermission ? "Requesting…" : "Allow microphone",
            primaryAction: {
                Task {
                    await viewModel.requestMicrophone(speechCapture: speechCapture)
                    viewModel.advance(from: onboardingPreferences)
                }
            },
            skipAction: { viewModel.advance(from: onboardingPreferences) }
        )
    }

    // MARK: - Notifications

    private var notificationsStep: some View {
        permissionStep(
            icon: "bell.fill",
            title: "Allow notifications",
            detail: "A gentle heads-up when your luteal phase starts, plus an optional daily log reminder. You can change these anytime in Settings.",
            primaryTitle: viewModel.isRequestingPermission ? "Requesting…" : "Allow notifications",
            primaryAction: {
                Task {
                    await viewModel.requestNotifications()
                    onboardingPreferences.markCompleted()
                }
            },
            skipAction: { onboardingPreferences.markCompleted() }
        )
    }

    // MARK: - Shared pieces

    private func permissionStep(
        icon: String,
        title: String,
        detail: String,
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        skipAction: @escaping () -> Void
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                permissionCard(icon: icon, title: title, detail: detail)

                HStack(spacing: 12) {
                    secondaryButton("Not now") {
                        skipAction()
                    }
                    Button(primaryTitle, action: primaryAction)
                        .buttonStyle(.borderedProminent)
                        .tint(theme.pain)
                        .disabled(viewModel.isRequestingPermission)
                }
            }
            .padding(24)
        }
    }

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.title2, design: .serif))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func permissionCard(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(theme.cycle)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(theme.line, lineWidth: 1)
        }
    }

    private var disclaimerRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(theme.cycle)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            Text(MedicalDisclaimer.shortLine)
                .font(.footnote)
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
            .tint(theme.pain)
            .frame(maxWidth: .infinity)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .tint(theme.muted)
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    OnboardingView(
        viewModel: OnboardingViewModel(),
        onboardingPreferences: OnboardingPreferences()
    )
    .environment(\.theme, .plumEmber)
    .environment(CycleService(provider: MockCycleDataProvider()))
    .environment(SpeechCapture(provider: MockSpeechRecognizer(transcript: "")))
    .environment(AppLockController())
}
