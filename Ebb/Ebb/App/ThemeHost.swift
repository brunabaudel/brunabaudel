import SwiftUI

/// Applies the effective theme from preferences + Ebb+ entitlement.
struct ThemeHost<Content: View>: View {
    @Environment(ThemePreferences.self) private var themePreferences
    @Environment(EntitlementsService.self) private var entitlements
    @ViewBuilder private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .environment(\.theme, themePreferences.effectiveTheme(isEbbPlus: entitlements.isEbbPlus))
    }
}
