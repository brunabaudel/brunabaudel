import Foundation

/// Parses raw classifier JSON and runs the schema validation gate.
enum ClassificationJSONParser {
    static func parse(_ raw: String, schema: SchemaConfig) throws -> [String: FieldValue] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [:] }

        let jsonText = extractJSONObject(from: trimmed)
        guard let data = jsonText.data(using: .utf8) else {
            throw SymptomClassifierError.invalidModelResponse
        }

        let decoded = try JSONDecoder().decode([String: FieldValue].self, from: data)
        return schema.validated(decoded)
    }

    private static func extractJSONObject(from text: String) -> String {
        if text.hasPrefix("{") {
            return text
        }

        if let fenceStart = text.range(of: "```"),
           let fenceEnd = text.range(of: "```", range: fenceStart.upperBound..<text.endIndex) {
            let inner = text[fenceStart.upperBound..<fenceEnd.lowerBound]
            let withoutLanguage = inner.hasPrefix("json")
                ? inner.dropFirst(4)
                : Substring(inner)
            return String(withoutLanguage).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }

        return text
    }
}
