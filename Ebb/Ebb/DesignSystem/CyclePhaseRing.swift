import SwiftUI

/// The signature cycle-phase ring from the UI board. Phase is fed by
/// `CycleService` from HealthKit flow data and logged bleeding.
struct CyclePhaseRing: View {
    let phase: CyclePhase
    let cycleDay: Int
    let cycleLength: Int
    var summary: String

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            ring
            VStack(alignment: .leading, spacing: 4) {
                Text(phase.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.cycle)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(theme.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(phase.displayName), day \(cycleDay) of \(cycleLength). \(summary)")
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(theme.line, lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(theme.cycle, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: progress)
            VStack(spacing: 2) {
                Text("\(cycleDay)")
                    .font(.system(.title2, design: .serif))
                    .foregroundStyle(theme.text)
                Text("DAY")
                    .font(.caption2.weight(.semibold))
                    .kerning(1.4)
                    .foregroundStyle(theme.muted)
            }
        }
        .frame(width: 76, height: 76)
        .accessibilityHidden(true)
    }

    private var progress: CGFloat {
        guard cycleLength > 0 else { return 0 }
        return min(max(CGFloat(cycleDay) / CGFloat(cycleLength), 0), 1)
    }
}

extension CyclePhase {
    var displayName: String {
        switch self {
        case .menstrual: "Menstrual"
        case .follicular: "Follicular"
        case .ovulation: "Ovulation"
        case .luteal: "Luteal"
        }
    }
}

#Preview {
    CyclePhaseRing(
        phase: .luteal,
        cycleDay: 22,
        cycleLength: 28,
        summary: "Luteal phase — a common window for hormonal migraines."
    )
    .padding()
    .background(Theme.plumEmber.base)
    .environment(\.theme, .plumEmber)
}
