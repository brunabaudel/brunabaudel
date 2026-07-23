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
                }
            }
            .frame(height: 72)

            phaseLabelsRow
                .padding(.top, 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(timelineAccessibilityLabel)
    }

    private var phaseLabelsRow: some View {
        GeometryReader { proxy in
            let totalDays = CGFloat(
                timeline.menstrualDayCount
                    + timeline.follicularDayCount
                    + timeline.lutealDayCount
            )
            let width = proxy.size.width

            HStack(spacing: 0) {
                phaseLabel(
                    "menstrual",
                    width: width * CGFloat(timeline.menstrualDayCount) / totalDays,
                    accent: false
                )
                phaseLabel(
                    "follicular",
                    width: width * CGFloat(timeline.follicularDayCount) / totalDays,
                    accent: false
                )
                phaseLabel(
                    "luteal",
                    width: width * CGFloat(timeline.lutealDayCount) / totalDays,
                    accent: true
                )
            }
        }
        .frame(height: 14)
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

    private func phaseLabel(_ text: String, width: CGFloat, accent: Bool) -> some View {
        Text(text)
            .font(.caption2.monospaced())
            .foregroundStyle(accent ? theme.cycle : theme.muted.opacity(0.75))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.center)
            .frame(width: max(width, 0), alignment: .center)
    }

    private func markerFraction(for cycleDay: Int) -> CGFloat {
        let span = max(timeline.cycleLength - 1, 1)
        return CGFloat(cycleDay - 1) / CGFloat(span)
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
            periodLength: 5,
            migraineCycleDays: [17, 20, 25],
            lutealStartFraction: 0.52,
            lutealEndFraction: 1
        )
    )
    .padding()
    .background(Theme.plumEmber.base)
    .environment(\.theme, .plumEmber)
}
