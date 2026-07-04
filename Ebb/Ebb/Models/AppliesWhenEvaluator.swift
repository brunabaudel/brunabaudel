import Foundation

/// Evaluates schema `appliesWhen` hints for progressive disclosure. These are
/// UI hints only — never validation rules (classification spec).
enum AppliesWhenEvaluator {
    /// Returns whether `field` should be visible given the current draft values.
    static func isVisible(field: SchemaField, values: [String: FieldValue]) -> Bool {
        guard let expression = field.appliesWhen else { return true }
        return evaluate(expression, values: values)
    }

    private static func evaluate(_ expression: String, values: [String: FieldValue]) -> Bool {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)

        // "field_key == true" | "field_key == false"
        if let equalsMatch = trimmed.firstMatch(of: /^(\w+)\s*==\s*(true|false)$/) {
            let key = String(equalsMatch.1)
            let expected = equalsMatch.2 == "true"
            guard case .boolean(let flag)? = values[key] else { return false }
            return flag == expected
        }

        // "field_key not empty"
        if let notEmptyMatch = trimmed.firstMatch(of: /^(\w+)\s+not\s+empty$/) {
            let key = String(notEmptyMatch.1)
            guard let value = values[key] else { return false }
            return !value.isEmpty
        }

        // Unknown expression — show the field rather than hide data the user
        // might need to enter manually.
        return true
    }
}

private extension FieldValue {
    var isEmpty: Bool {
        switch self {
        case .choices(let keys): keys.isEmpty
        case .choice, .boolean, .scale: false
        }
    }
}
