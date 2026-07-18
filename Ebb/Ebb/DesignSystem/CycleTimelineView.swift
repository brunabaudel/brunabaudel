import SwiftUI

/// Horizontal cycle axis with luteal band and migraine markers (UI board §05).
struct CycleTimelineView: View {
    let timeline: PatternStatsEngine.CycleTimeline

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("day 1")
                .font(.caption2.monospaced())
                .foregroundStyle(theme.muted.opacity(0.75))

            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(theme.line)
                        .frame(height: 2)
                        .offset(y: 54)

                    RoundedRectangle(cornerRadius: 7)
                        .fill(theme.cycleDim.opacity(0.55))
                        .frame(
                            width: width * (timeline.lutealEndFraction - timeline.lutealStartFraction),
                            height: 14
                        )
                        .offset(x: width * timeline.lutealStartFraction, y: 48)

                    ForEach(timeline.migraineCycleDays, id: \.self) { day in
                        migraineMarker(at: day, width: width)
                    }

                    phaseLabel("menstrual", at: menstrualFraction, width: width, accent: false)
                    phaseLabel("follicular", at: follicularFraction, width: width, accent: false)
                    phaseLabel("luteal", at: lutealLabelFraction, width: width, accent: true)
                }
            }
            .frame(height: 90)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(timelineAccessibilityLabel)
    }

    @ViewBuilder
    private func migraineMarker(at cycleDay: Int, width: CGFloat) -> some View {
        let fraction = markerFraction(for: cycleDay)
        Circle()
            .fill(theme.pain)
            .frame(width: 13, height: 13)
            .overlay {
                Circle()
                    .strokeBorder(theme.base, lineWidth: 2)
            }
            .shadow(color: theme.pain.opacity(0.6), radius: 3)
            .offset(x: width * fraction - 6.5, y: 48)
    }

    private func phaseLabel(_ text: String, at fraction: Double, width: CGFloat, accent: Bool) -> some View {
        Text(text)
            .font(.caption2.monospaced())
            .foregroundStyle(accent ? theme.cycle : theme.muted.opacity(0.75))
            .offset(x: width * fraction, y: 72)
    }

    private func markerFraction(for cycleDay: Int) -> CGFloat {
        let span = max(timeline.cycleLength - 1, 1)
        return CGFloat(cycleDay - 1) / CGFloat(span)
    }

    private var menstrualFraction: Double {
        Double(max(timeline.cycleLength / 7, 2) - 1) / Double(max(timeline.cycleLength - 1, 1))
    }

    private var follicularFraction: Double {
        13.0 / Double(max(timeline.cycleLength - 1, 1)) * 0.55
    }

    private var lutealLabelFraction: Double {
        min(timeline.lutealStartFraction + 0.18, 0.92)
    }

    private var timelineAccessibilityLabel: String {
        let days = timeline.migraineCycleDays.map(String.init).joined(separator: ", ")
        if days.isEmpty {
            return "Cycle timeline, no migraines marked yet"
        }
        return "Cycle timeline with migraines on days \(days)"
    }
}

#Preview {
    CycleTimelineView(
        timeline: PatternStatsEngine.CycleTimeline(
            cycleLength: 28,
            migraineCycleDays: [17, 20, 25],
            lutealStartFraction: 0.52,
            lutealEndFraction: 1
        )
    )
    .padding()
    .background(Theme.plumEmber.base)
    .environment(\.theme, .plumEmber)
}
