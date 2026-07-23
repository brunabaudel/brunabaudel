import SwiftUI

/// Presents the Ebb+ plan sheet with entitlements wired through — sheets do not
/// always inherit custom `@Observable` environment objects reliably.
struct EbbPlusPaywallSheet: View {
    @Environment(EntitlementsService.self) private var entitlements

    var body: some View {
        EbbPlusPlansSheet()
            .environment(entitlements)
    }
}
