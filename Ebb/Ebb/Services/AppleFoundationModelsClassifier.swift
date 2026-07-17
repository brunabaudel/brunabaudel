#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// On-device Apple Intelligence classifier. Falls back to `SynonymSymptomClassifier`
/// when the system model is unavailable (common in the EU on some iOS builds).
@available(iOS 26.0, *)
struct AppleFoundationModelsClassifier: SymptomClassifier {
    let providerName = "Apple Foundation Models"

    var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    func classify(transcript: String, schema: SchemaConfig) async throws -> [String: FieldValue] {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SymptomClassifierError.emptyTranscript
        }
        guard isAvailable else {
            throw SymptomClassifierError.modelUnavailable
        }

        let instructions = ClassificationPromptBuilder.systemPrompt(schema: schema)
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(
            to: ClassificationPromptBuilder.userPrompt(transcript: trimmed)
        )
        return try ClassificationJSONParser.parse(response.content, schema: schema)
    }
}
#endif
