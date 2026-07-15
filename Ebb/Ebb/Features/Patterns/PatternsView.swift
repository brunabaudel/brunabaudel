import SwiftUI

struct PatternsView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Patterns", systemImage: "chart.line.uptrend.xyaxis")
            } description: {
                Text("Cycle timeline and trigger correlations arrive in Phase 7.")
            }
            .foregroundStyle(theme.text)
            .background(theme.base)
            .navigationTitle("Patterns")
        }
    }
}

#Preview {
    PatternsView()
        .environment(\.theme, .plumEmber)
}
