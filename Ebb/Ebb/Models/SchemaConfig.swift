import Foundation

/// The platform-neutral symptom schema, loaded from the bundled `symptom-schema.json`.
///
/// This is the single source of truth for both the UI controls and (later) the
/// classifier vocabulary — see `docs/symptom-tracker-classification-spec.md`.
/// It is deliberately plain data, passed down by value, not a service.
struct SchemaConfig: Equatable, Sendable, Decodable {
    let schemaVersion: String
    let domain: String
    let fields: [SchemaField]

    func field(forKey key: String) -> SchemaField? {
        fields.first { $0.key == key }
    }
}

/// One entry in the schema's `fields` array: a symptom, trigger, or context
/// dimension. `type` decides both the UI control and the shape of `FieldValue`
/// the field accepts.
struct SchemaField: Equatable, Sendable, Identifiable {
    let key: String
    let label: String
    let type: FieldType
    let isRequired: Bool
    let meaning: String?
    /// Bounds for `.scale` fields (e.g. severity 1...5, cramps 0...5).
    let range: ClosedRange<Int>?
    /// Human wording per scale step (e.g. 1 → "barely there").
    let scaleLabels: [Int: String]
    /// Allowed options for `.singleEnum` / `.multiEnum` fields.
    let values: [FieldValueOption]
    /// Progressive-disclosure hint (spec: a UI hint, not a validation rule).
    /// Kept as the raw expression string; Phase 1 interprets it.
    let appliesWhen: String?

    var id: String { key }

    var allowedValueKeys: Set<String> {
        Set(values.map(\.key))
    }
}

enum FieldType: String, Decodable, Sendable {
    case boolean
    case scale
    case singleEnum = "enum"
    case multiEnum = "multi_enum"
}

/// An allowed value of an enum-like field. `synonyms` are model-only vocabulary:
/// they never render as buttons and exist to widen what the classifier recognizes.
struct FieldValueOption: Equatable, Sendable, Identifiable {
    let key: String
    let label: String
    let synonyms: [String]

    var id: String { key }
}

// MARK: - Decoding

extension SchemaField: Decodable {
    private enum CodingKeys: String, CodingKey {
        case key, label, type, required, meaning, range, labels, values, appliesWhen
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        label = try container.decode(String.self, forKey: .label)
        type = try container.decode(FieldType.self, forKey: .type)
        isRequired = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
        meaning = try container.decodeIfPresent(String.self, forKey: .meaning)
        appliesWhen = try container.decodeIfPresent(String.self, forKey: .appliesWhen)
        values = try container.decodeIfPresent([FieldValueOption].self, forKey: .values) ?? []

        if let bounds = try container.decodeIfPresent([Int].self, forKey: .range) {
            guard bounds.count == 2, bounds[0] <= bounds[1] else {
                throw DecodingError.dataCorruptedError(
                    forKey: .range,
                    in: container,
                    debugDescription: "range must be [min, max] with min <= max, got \(bounds)"
                )
            }
            range = bounds[0]...bounds[1]
        } else {
            range = nil
        }

        // JSON object keys are strings; scale steps are integers.
        let rawLabels = try container.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
        scaleLabels = rawLabels.reduce(into: [:]) { result, pair in
            guard let step = Int(pair.key) else { return }
            result[step] = pair.value
        }
    }
}

extension FieldValueOption: Decodable {
    private enum CodingKeys: String, CodingKey {
        case key, label, synonyms
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        label = try container.decode(String.self, forKey: .label)
        synonyms = try container.decodeIfPresent([String].self, forKey: .synonyms) ?? []
    }
}

// MARK: - Loading

extension SchemaConfig {
    enum LoadError: Error, Equatable {
        case resourceNotFound(String)
    }

    static let resourceName = "symptom-schema"

    static func load(from bundle: Bundle = .main) throws -> SchemaConfig {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw LoadError.resourceNotFound("\(resourceName).json")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SchemaConfig.self, from: data)
    }
}

// MARK: - Validation gate

extension SchemaConfig {
    /// Drops every key and value the schema does not allow, and returns what
    /// survives. Belt-and-suspenders with the classifier's constrained decoding
    /// (spec, "Notes for whoever implements this") — and the same gate protects
    /// manual code paths. Never throws: off-menu input is silently discarded
    /// because omission is always a safe answer.
    func validated(_ values: [String: FieldValue]) -> [String: FieldValue] {
        values.reduce(into: [:]) { result, pair in
            guard let field = field(forKey: pair.key),
                  let value = field.validated(pair.value) else { return }
            result[pair.key] = value
        }
    }
}

extension SchemaField {
    /// Returns the value if it fits this field's type and vocabulary, a filtered
    /// copy for partially valid multi-selections, or nil when nothing survives.
    func validated(_ value: FieldValue) -> FieldValue? {
        switch (type, value) {
        case (.boolean, .boolean):
            return value

        case (.scale, .scale(let step)):
            guard let range, range.contains(step) else { return nil }
            return value

        case (.singleEnum, .choice(let choice)):
            return allowedValueKeys.contains(choice) ? value : nil

        case (.multiEnum, .choices(let choices)):
            var seen = Set<String>()
            let kept = choices.filter { allowedValueKeys.contains($0) && seen.insert($0).inserted }
            return kept.isEmpty ? nil : .choices(kept)

        default:
            return nil
        }
    }
}
