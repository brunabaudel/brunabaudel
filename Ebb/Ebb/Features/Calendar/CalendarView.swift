import SwiftUI

struct CalendarView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Calendar", systemImage: "calendar")
            } description: {
                Text("Month view with luteal tint and migraine dots arrives in Phase 3.")
            }
            .foregroundStyle(theme.text)
            .background(theme.base)
            .navigationTitle("Calendar")
        }
    }
}

#Preview {
    CalendarView()
        .environment(\.theme, .plumEmber)
}
