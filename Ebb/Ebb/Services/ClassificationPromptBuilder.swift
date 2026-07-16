import Foundation

/// Assembles the classifier system prompt and few-shot block from the bundled
/// schema — `[ALLOWED_FIELDS]` is never pasted by hand (classification spec).
enum ClassificationPromptBuilder {
    static let fewShotBlock = """
    **1. Multi-field + implication + synonym**
    User: "dull one on the right, barely there, worse when I move"
    {
      "migraine_present": true,
      "severity": 1,
      "location": ["right"],
      "quality": ["dull"],
      "worse_with_movement": true
    }

    **2. Negation + multi-location (severity not stated → omitted)**
    User: "pounding behind my left eye, the light is killing me but no nausea"
    {
      "migraine_present": true,
      "location": ["left", "behind_eye"],
      "quality": ["throbbing"],
      "associated_symptoms": ["light_sensitivity"]
    }

    **3. Period + trigger + relief with partial effect (foreign word handled)**
    User: "heavy period, cramps são fortes, tomei dois ibuprofeno e ajudou um pouco. dormi mal também"
    {
      "bleeding": "heavy",
      "cramps_severity": 4,
      "relief_taken": ["ibuprofen"],
      "relief_effect": "partial",
      "triggers": ["poor_sleep"]
    }

    **4. Pure ambiguity → empty object**
    User: "feeling rough today"
    {}
    """

    static func systemPrompt(schema: SchemaConfig) -> String {
        """
        You are a symptom-logging classifier running on-device inside a health app.
        The user describes how they feel in plain language. Your only job is to map
        what they ACTUALLY said onto the fixed fields and allowed values below, and
        return JSON. You do not interpret, diagnose, advise, or add anything the user
        did not say.

        OUTPUT
        - Return ONLY a JSON object. No prose, no markdown, no code fences.
        - Use the exact field keys and value keys listed. Never invent a key or value.
        - multi_enum fields → array of value keys. enum → one value key.
          boolean → true/false. scale → an integer in range.

        CORE RULES
        1. Only set a field if the user clearly expressed it. If something isn't
           mentioned, OMIT the field entirely. Unset is always safe; guessing is not.
           The user confirms or fills the rest by tapping — your job is to catch what
           was said, not to complete the form.
        2. Handle negation. "no nausea", "wasn't sensitive to light", "didn't take
           anything" mean do NOT add that value. For a boolean, set it false. Never
           log a symptom the user denied.
        3. One sentence can map to several fields. Decompose it fully.
           "dull one on the right, worse when I move" →
           location:["right"], quality:["dull"], worse_with_movement:true.
        4. Map synonyms and informal or non-English words to the closest allowed key
           (e.g. "pounding"→throbbing, "mandíbula"→jaw). If a word has no clear match,
           OMIT it — do not force the nearest pill.
        5. Severity / cramps words → numbers: "barely there"→1, "mild"→2,
           "moderate"→3, "bad"/"severe"→4, "can't function"/"worst ever"→5.
        6. If the user mentions a headache at all, set migraine_present:true. If they
           describe only period symptoms with no headache, omit migraine_present's
           dependent fields.
        7. If nothing maps cleanly (e.g. "feeling rough today"), return {} and let the
           user fill it in by hand. An empty object is a valid, correct answer.

        ALLOWED FIELDS
        \(allowedFieldsBlock(schema: schema))

        FEW-SHOT EXAMPLES
        \(fewShotBlock)
        """
    }

    static func userPrompt(transcript: String) -> String {
        """
        User: "\(transcript)"
        """
    }

    static func allowedFieldsBlock(schema: SchemaConfig) -> String {
        schema.fields.map { field in
            var lines = ["- \(field.key) (\(field.type.rawValue)): \(field.label)"]
            if let range = field.range {
                lines.append("  range: \(range.lowerBound)...\(range.upperBound)")
                if !field.scaleLabels.isEmpty {
                    let labels = field.scaleLabels.sorted { $0.key < $1.key }
                        .map { "    \($0.key): \($0.value)" }
                        .joined(separator: "\n")
                    lines.append("  labels:\n\(labels)")
                }
            }
            if !field.values.isEmpty {
                let values = field.values.map { option in
                    let synonymText = option.synonyms.isEmpty
                        ? ""
                        : " — synonyms: \(option.synonyms.joined(separator: ", "))"
                    return "    \(option.key): \(option.label)\(synonymText)"
                }.joined(separator: "\n")
                lines.append("  values:\n\(values)")
            }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n")
    }
}
