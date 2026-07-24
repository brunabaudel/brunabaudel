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
            return "Migraine"
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
        let markers = todayRowMarkers(entry, schema: schema)
        guard !markers.isEmpty else { return nil }
        return markers.map(\.label).joined(separator: " · ")
    }

    /// Prose line under the title — mock B `.desc` style.
    static func todayRowDescription(_ entry: SymptomEntry, schema: SchemaConfig) -> String? {
        let values = entry.fieldValues
        var leadParts: [String] = []
        var trailParts: [String] = []

        if values["migraine_present"] == .boolean(true) {
            var head = ""
            if case .scale(let step)? = values["severity"],
               let label = schema.field(forKey: "severity")?.scaleLabels[step] {
                head = label.capitalized
            }

            var detailBits: [String] = []
            for label in choiceLabelList(for: "location", in: values, schema: schema) {
                detailBits.append(label.lowercased())
            }
            for label in choiceLabelList(for: "quality", in: values, schema: schema) {
                detailBits.append(label.lowercased())
            }

            if !head.isEmpty, !detailBits.isEmpty {
                leadParts.append("\(head) — \(listPhrase(detailBits))")
            } else if !head.isEmpty {
                leadParts.append(head)
            } else if !detailBits.isEmpty {
                leadParts.append(listPhrase(detailBits).capitalized)
            }
        } else if let bleeding = choiceLabel(for: "bleeding", in: values, schema: schema),
                  bleeding.lowercased() != "none" {
            if bleeding.lowercased() == "spotting" {
                leadParts.append("Spotting")
            } else {
                leadParts.append("\(bleeding) bleeding")
            }
        }

        if case .scale(let step)? = values["cramps_severity"], step > 0,
           let label = schema.field(forKey: "cramps_severity")?.scaleLabels[step] {
            leadParts.append("\(label) cramps")
        }

        if let relief = choiceLabels(for: "relief_taken", in: values, schema: schema), !relief.isEmpty {
            trailParts.append("Took \(relief)")
        }
        if let triggers = choiceLabels(for: "triggers", in: values, schema: schema), !triggers.isEmpty {
            let prefix = triggers.contains(" and ") || triggers.contains(",")
                ? "Possible triggers: "
                : "Possible trigger: "
            trailParts.append(prefix + triggers)
        }

        let lead = leadParts.joined(separator: ", ")
        let trail = trailParts.joined(separator: ". ")
        switch (lead.isEmpty, trail.isEmpty) {
        case (true, true):
            return nil
        case (false, true):
            return lead + "."
        case (true, false):
            return trail + "."
        case (false, false):
            return "\(lead). \(trail)."
        }
    }

    /// Tag chips for a Today row — pain / cycle / neutral, matching mock B markers.
    static func todayRowMarkers(_ entry: SymptomEntry, schema: SchemaConfig) -> [TodayRowMarker] {
        let values = entry.fieldValues
        var markers: [TodayRowMarker] = []

        if values["migraine_present"] == .boolean(true),
           case .scale(let step)? = values["severity"],
           let label = schema.field(forKey: "severity")?.scaleLabels[step] {
            markers.append(TodayRowMarker(label: label.lowercased(), kind: .pain))
        }

        for label in choiceLabelList(for: "location", in: values, schema: schema) {
            markers.append(TodayRowMarker(label: label.lowercased(), kind: .pain))
        }
        for label in choiceLabelList(for: "associated_symptoms", in: values, schema: schema) {
            markers.append(TodayRowMarker(label: label.lowercased(), kind: .pain))
        }

        if let bleeding = choiceLabel(for: "bleeding", in: values, schema: schema),
           bleeding.lowercased() != "none" {
            markers.append(TodayRowMarker(label: bleeding.lowercased(), kind: .cycle))
        }

        if case .scale(let step)? = values["cramps_severity"], step > 0,
           let label = schema.field(forKey: "cramps_severity")?.scaleLabels[step] {
            let title = todayRowTitle(entry, schema: schema)
            let chip = "\(label.lowercased()) cramps"
            if !title.localizedCaseInsensitiveContains("cramps") {
                markers.append(TodayRowMarker(label: chip, kind: .cycle))
            }
        }

        for label in choiceLabelList(for: "triggers", in: values, schema: schema) {
            markers.append(TodayRowMarker(label: label.lowercased(), kind: .neutral))
        }
        for label in choiceLabelList(for: "relief_taken", in: values, schema: schema) {
            markers.append(TodayRowMarker(label: label.lowercased(), kind: .neutral))
        }

        return markers
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

/// Compact tag chip for Today / timeline-style entry rows (mock B markers).
struct TodayRowMarker: Equatable, Sendable, Identifiable {
    enum Kind: Equatable, Sendable {
        case pain
        case cycle
        case neutral
    }

    var id: String { "\(kind)-\(label)" }
    let label: String
    let kind: Kind
}
