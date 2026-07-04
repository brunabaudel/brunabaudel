import SwiftUI

struct TodayView: View {
    let schema: SchemaConfig

    @Environment(\.theme) private var theme
    @State private var showTapLog = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    CyclePhaseRing(
                        phase: .luteal,
                        cycleDay: 22,
                        cycleLength: 28,
                        summary: "Placeholder until HealthKit connects in Phase 4."
                    )
                    logButtons
                }
                .padding(20)
            }
            .background(theme.base)
            .foregroundStyle(theme.text)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showTapLog) {
                TapLogView(schema: schema)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today")
                .font(.system(.title, design: .serif))
            Text(Date.now.formatted(date: .complete, time: .omitted))
                .font(.footnote)
                .foregroundStyle(theme.muted)
        }
    }

    private var logButtons: some View {
        HStack(spacing: 11) {
            Button {} label: {
                logButton(
                    title: "Talk",
                    hint: "Coming in Phase 5",
                    style: .talk,
                    systemImage: "mic.fill"
                )
            }
            .disabled(true)

            Button { showTapLog = true } label: {
                logButton(
                    title: "Tap",
                    hint: "Log with buttons",
                    style: .tap,
                    systemImage: "hand.tap.fill"
                )
            }
        }
    }

    private enum LogButtonStyle { case talk, tap }

    private func logButton(
        title: String,
        hint: String,
        style: LogButtonStyle,
        systemImage: String
    ) -> some View {
        VStack(spacing: 3) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
            Text(hint)
                .font(.caption2)
                .opacity(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .foregroundStyle(style == .talk ? theme.onPain : theme.text)
        .background {
            if style == .talk {
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.pain)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(theme.line, lineWidth: 1)
            }
        }
    }
}

#Preview {
    TodayView(schema: try! SchemaConfig.load())
        .environment(\.theme, .plumEmber)
}
