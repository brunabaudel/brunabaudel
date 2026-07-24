import Foundation

/// Template-driven plain-language summaries for Today. The app computes the
/// facts; no model phrasing (product spec: summaries are the weak spot for
/// small local models).
enum DaySummaryBuilder {
    static func todaySummary(
        entries: [SymptomEntry],
        schema: SchemaConfig,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> String {
        let todays = entries
            .filter { calendar.isDate($0.timestamp, inSameDayAs: now) }
            .sorted { $0.timestamp > $1.timestamp }

        guard !todays.isEmpty else { return "Nothing logged yet today." }

        if todays.count == 1 {
            return describe(todays[0], schema: schema)
        }
        let latest = todays[0]
        return "\(todays.count) logs today. Latest: \(describe(latest, schema: schema, compact: true))"
    }

    static func describe(
        _ entry: SymptomEntry,
        schema: SchemaConfig,
        compact: Bool = false
    ) -> String {
        let values = entry.fieldValues
        var parts: [String] = []

        if values["migraine_present"] == .boolean(true) {
            var migraine = "Migraine"
            if case .scale(let step)? = values["severity"],
               let label = schema.field(forKey: "severity")?.scaleLabels[step] {
                migraine += compact ? " (\(label))" : " — \(label)"
            }
            if let locations = choiceLabels(for: "location", in: values, schema: schema), !locations.isEmpty {
                migraine += ", \(locations)"
            }
            parts.append(migraine)
        } else if values["migraine_present"] == .boolean(false) {
            parts.append("No migraine")
        }

        if let bleeding = choiceLabel(for: "bleeding", in: values, schema: schema),
           bleeding.lowercased() != "none" {
            parts.append(bleeding + " bleeding")
        }

        if case .scale(let step)? = values["cramps_severity"], step > 0,
           let label = schema.field(forKey: "cramps_severity")?.scaleLabels[step] {
            parts.append("\(label) cramps")
        }

        if let triggers = choiceLabels(for: "triggers", in: values, schema: schema), !triggers.isEmpty {
            let prefix = compact ? "triggers: " : "Possible triggers: "
            parts.append(prefix + triggers)
        }

        if parts.isEmpty {
            return compact ? "symptom log" : "Symptom log — no details filled in yet."
        }
        return parts.joined(separator: compact ? "; " : ". ") + (compact ? "" : ".")
    }

    private static func choiceLabel(
        for key: String,
        in values: [String: FieldValue],
        schema: SchemaConfig
    ) -> String? {
        guard let field = schema.field(forKey: key) else { return nil }
        switch values[key] {
        case .choice(let choice):
            return field.values.first { $0.key == choice }?.label
        default:
            return nil
        }
    }

    private static func choiceLabels(
        for key: String,
        in values: [String: FieldValue],
        schema: SchemaConfig
    ) -> String? {
        guard let field = schema.field(forKey: key) else { return nil }
        switch values[key] {
        case .choices(let keys):
            let labels = keys.compactMap { choice in field.values.first { $0.key == choice }?.label }
            guard !labels.isEmpty else { return nil }
            return listPhrase(labels)
        default:
            return nil
        }
    }

    private static func listPhrase(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0].lowercased()
        case 2: return "\(items[0].lowercased()) and \(items[1].lowercased())"
        default:
            let head = items.dropLast().map { $0.lowercased() }.joined(separator: ", ")
            return "\(head), and \(items.last!.lowercased())"
        }
    }

    // MARK: - Today row presentation

    static func entryAccent(_ entry: SymptomEntry) -> FieldAccent {
        let values = entry.fieldValues
        if values["migraine_present"] == .boolean(true) {
            return .pain
        }
        if let bleeding = values["bleeding"],
           case .choice(let key) = bleeding,
           key != "none" {
            return .cycle
        }
        if case .scale(let step)? = values["cramps_severity"], step > 0 {
            return .cycle
        }
        return .pain
    }

    static func todayRowTitle(_ entry: SymptomEntry, schema: SchemaConfig) -> String {
        let values = entry.fieldValues
        if values["migraine_present"] == .boolean(true) {
            var title = "Migraine"
            if case .scale(let step)? = values["severity"],
               let label = schema.field(forKey: "severity")?.scaleLabels[step] {
                title += " — \(label.lowercased())"
            }
            return title
        }
        if let bleeding = choiceLabel(for: "bleeding", in: values, schema: schema),
           bleeding.lowercased() != "none" {
            return bleeding
        }
        if case .scale(let step)? = values["cramps_severity"], step > 0,
           let label = schema.field(forKey: "cramps_severity")?.scaleLabels[step] {
            return "\(label.capitalized) cramps"
        }
        if values["migraine_present"] == .boolean(false) {
            return "No migraine"
        }
        return "Symptom log"
    }

    static func todayRowDetail(_ entry: SymptomEntry, schema: SchemaConfig) -> String? {
        let values = entry.fieldValues
        var parts: [String] = []

        for label in choiceLabelList(for: "location", in: values, schema: schema) {
            parts.append(label)
        }
        for label in choiceLabelList(for: "associated_symptoms", in: values, schema: schema) {
            parts.append(label.lowercased())
        }
        for label in choiceLabelList(for: "triggers", in: values, schema: schema) {
            parts.append(label.lowercased())
        }
        for label in choiceLabelList(for: "relief_taken", in: values, schema: schema) {
            parts.append(label.lowercased())
        }

        let title = todayRowTitle(entry, schema: schema)
        if !title.localizedCaseInsensitiveContains("cramps"),
           case .scale(let step)? = values["cramps_severity"], step > 0,
           let label = schema.field(forKey: "cramps_severity")?.scaleLabels[step] {
            parts.append("\(label.capitalized) cramps")
        }

        if let phase = entry.cyclePhase {
            parts.append("\(phase.displayName.lowercased()) phase")
        }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    static func painSeverity(for entry: SymptomEntry) -> Int? {
        guard entry.fieldValues["migraine_present"] == .boolean(true),
              case .scale(let step)? = entry.fieldValues["severity"] else {
            return nil
        }
        return step
    }

    static func isCycleIntensityEntry(_ entry: SymptomEntry) -> Bool {
        entryAccent(entry) == .cycle && painSeverity(for: entry) == nil
    }

    private static func choiceLabelList(
        for key: String,
        in values: [String: FieldValue],
        schema: SchemaConfig
    ) -> [String] {
        guard let field = schema.field(forKey: key) else { return [] }
        switch values[key] {
        case .choices(let keys):
            return keys.compactMap { choice in
                field.values.first { $0.key == choice }?.label
            }
        case .choice(let key):
            if let label = field.values.first(where: { $0.key == key })?.label {
                return [label]
            }
            return []
        default:
            return []
        }
    }
}
