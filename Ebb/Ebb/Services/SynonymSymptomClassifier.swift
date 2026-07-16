import Foundation

/// Rule-based on-device fallback when Apple Foundation Models is unavailable
/// (EU/simulator). Matches schema synonyms and the spec's few-shot patterns so
/// Talk → Confirm still works offline.
struct SynonymSymptomClassifier: SymptomClassifier {
    let providerName = "Synonym (on-device)"

    func classify(transcript: String, schema: SchemaConfig) async throws -> [String: FieldValue] {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SymptomClassifierError.emptyTranscript
        }

        var matcher = TranscriptMatcher(transcript: trimmed, schema: schema)
        return matcher.classify()
    }
}

// MARK: - Matcher

private struct TranscriptMatcher {
    let normalized: String
    let schema: SchemaConfig
    private var result: [String: FieldValue] = [:]

    init(transcript: String, schema: SchemaConfig) {
        normalized = transcript.lowercased()
        self.schema = schema
    }

    mutating func classify() -> [String: FieldValue] {
        matchEnumLikeFields()
        matchBooleanPhrases()
        matchScales()
        inferMigrainePresent()
        return schema.validated(result)
    }

    private mutating func matchEnumLikeFields() {
        for field in schema.fields {
            switch field.type {
            case .singleEnum:
                if let match = firstEnumMatch(in: field) {
                    result[field.key] = .choice(match)
                }
            case .multiEnum:
                let matches = allEnumMatches(in: field)
                if !matches.isEmpty {
                    result[field.key] = .choices(matches)
                }
            case .boolean, .scale:
                continue
            }
        }
    }

    private mutating func matchBooleanPhrases() {
        for (fieldKey, phrases) in Self.booleanTruePhrases {
            guard schema.field(forKey: fieldKey)?.type == .boolean else { continue }
            if phrases.contains(where: { phraseMatches($0) && !isNegated(phrase: $0) }) {
                result[fieldKey] = .boolean(true)
            }
        }

        for (fieldKey, phrases) in Self.booleanFalsePhrases {
            guard schema.field(forKey: fieldKey)?.type == .boolean else { continue }
            if phrases.contains(where: { phraseMatches($0) }) {
                result[fieldKey] = .boolean(false)
            }
        }
    }

    private mutating func matchScales() {
        for field in schema.fields where field.type == .scale {
            guard let range = field.range else { continue }

            if field.key == "cramps_severity", !normalized.contains("cramp") {
                continue
            }

            if field.key == "severity", !mentionsMigraineContext() {
                continue
            }

            if let step = bestScaleMatch(for: field, range: range) {
                result[field.key] = .scale(step)
            }
        }
    }

    private mutating func inferMigrainePresent() {
        guard schema.field(forKey: "migraine_present")?.type == .boolean else { return }
        if result["migraine_present"] != nil { return }

        let migraineFieldKeys: Set<String> = [
            "severity", "location", "quality", "worse_with_movement", "aura",
        ]
        if migraineFieldKeys.contains(where: { result[$0] != nil }) {
            result["migraine_present"] = .boolean(true)
            return
        }

        if Self.headachePhrases.contains(where: { phraseMatches($0) && !isNegated(phrase: $0) }) {
            result["migraine_present"] = .boolean(true)
        }
    }

    private func firstEnumMatch(in field: SchemaField) -> String? {
        let candidates = enumCandidates(for: field)
        return candidates
            .filter { phraseMatches($0.phrase) && !isNegated(phrase: $0.phrase) }
            .max(by: { $0.phrase.count < $1.phrase.count })?
            .valueKey
    }

    private func allEnumMatches(in field: SchemaField) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        let candidates = enumCandidates(for: field)
            .filter { phraseMatches($0.phrase) && !isNegated(phrase: $0.phrase) }
            .sorted { $0.phrase.count > $1.phrase.count }

        for candidate in candidates {
            if seen.insert(candidate.valueKey).inserted {
                ordered.append(candidate.valueKey)
            }
        }
        return ordered
    }

    private func enumCandidates(for field: SchemaField) -> [(phrase: String, valueKey: String)] {
        field.values.flatMap { option in
            var phrases = option.synonyms.map { $0.lowercased() }
            phrases.append(option.label.lowercased())
            phrases.append(option.key.replacingOccurrences(of: "_", with: " "))
            return phrases.map { (phrase: $0, valueKey: option.key) }
        }
    }

    private func bestScaleMatch(for field: SchemaField, range: ClosedRange<Int>) -> Int? {
        var best: (step: Int, phraseLength: Int)?

        for (step, label) in field.scaleLabels where range.contains(step) {
            let phrase = label.lowercased()
            if phraseMatches(phrase), !isNegated(phrase: phrase) {
                best = preferredScaleMatch(current: best, step: step, phraseLength: phrase.count)
            }
        }

        for (phrase, step) in Self.globalSeverityPhrases where range.contains(step) {
            if phraseMatches(phrase), !isNegated(phrase: phrase) {
                best = preferredScaleMatch(current: best, step: step, phraseLength: phrase.count)
            }
        }

        return best?.step
    }

    private func preferredScaleMatch(
        current: (step: Int, phraseLength: Int)?,
        step: Int,
        phraseLength: Int
    ) -> (step: Int, phraseLength: Int) {
        guard let current else { return (step, phraseLength) }
        if phraseLength > current.phraseLength {
            return (step, phraseLength)
        }
        return current
    }

    private func mentionsMigraineContext() -> Bool {
        result["migraine_present"] == .boolean(true)
            || Self.headachePhrases.contains(where: { phraseMatches($0) && !isNegated(phrase: $0) })
            || ["severity", "location", "quality", "worse_with_movement", "aura"]
                .contains(where: { result[$0] != nil })
    }

    private func phraseMatches(_ phrase: String) -> Bool {
        guard !phrase.isEmpty else { return false }
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        let pattern = "\\b\(escaped)\\b"
        return normalized.range(of: pattern, options: .regularExpression) != nil
    }

    private func isNegated(phrase: String) -> Bool {
        let patterns = [
            "no \(phrase)",
            "not \(phrase)",
            "without \(phrase)",
            "never \(phrase)",
            "but no \(phrase)",
            "without any \(phrase)",
        ]
        return patterns.contains(where: { normalized.contains($0) })
    }

    private static let headachePhrases = [
        "headache", "migraine", "head pain", "head hurts", "head ache",
    ]

    private static let booleanTruePhrases: [String: [String]] = [
        "worse_with_movement": [
            "worse when i move",
            "worse with movement",
            "moving makes it worse",
            "movement makes it worse",
        ],
    ]

    private static let booleanFalsePhrases: [String: [String]] = [
        "worse_with_movement": [
            "not worse with movement",
            "not worse when i move",
        ],
    ]

    private static let globalSeverityPhrases: [(String, Int)] = [
        ("barely there", 1),
        ("mild", 2),
        ("moderate", 3),
        ("bad", 4),
        ("severe", 4),
        ("fortes", 4),
        ("forte", 4),
        ("can't function", 5),
        ("cant function", 5),
        ("worst ever", 5),
        ("disabling", 5),
    ]
}
