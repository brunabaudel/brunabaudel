import SwiftUI

/// Which semantic accent a field draws from. Warm = pain/symptom, cool = cycle.
enum FieldAccent: Sendable {
    case pain
    case cycle

    func accentColor(in theme: Theme) -> Color {
        switch self {
        case .pain: theme.pain
        case .cycle: theme.cycle
        }
    }

    func dimColor(in theme: Theme) -> Color {
        switch self {
        case .pain: theme.painDim
        case .cycle: theme.cycleDim
        }
    }

    func onAccentColor(in theme: Theme) -> Color {
        switch self {
        case .pain: theme.onPain
        case .cycle: theme.text
        }
    }
}

extension SchemaField {
    /// Maps schema fields to the warm/cool accent rule from the product spec.
    var accent: FieldAccent {
        switch key {
        case "bleeding", "cramps_severity":
            .cycle
        default:
            .pain
        }
    }
}
