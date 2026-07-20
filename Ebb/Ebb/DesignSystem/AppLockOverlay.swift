import SwiftUI

/// Blocks the app until local authentication succeeds when app lock is enabled.
struct AppLockOverlay: View {
    @Environment(\.theme) private var theme
    @Environment(AppLockController.self) private var appLock

    var body: some View {
        ZStack {
            theme.base.opacity(0.96)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(theme.muted)

                Text("Ebb is locked")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.text)

                Text("Use \(appLock.lockMethodLabel) to open your log.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.muted)

                if let message = appLock.lastErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.pain)
                }

                Button("Unlock") {
                    Task { await appLock.authenticate(reason: "Unlock Ebb") }
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.pain)
                .disabled(appLock.isAuthenticating)
            }
            .padding(32)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("App locked")
    }
}

#Preview {
    AppLockOverlay()
        .environment(\.theme, .plumEmber)
        .environment(AppLockController())
}
