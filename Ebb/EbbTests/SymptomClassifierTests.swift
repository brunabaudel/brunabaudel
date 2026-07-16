import Foundation
import Testing
@testable import Ebb

@Suite("Synonym classifier — few-shot failure modes")
struct SynonymSymptomClassifierTests {
    let schema = try! SchemaConfig.load(from: .main)
    let classifier = SynonymSymptomClassifier()

    @Test func multiFieldDecomposition() async throws {
        let result = try await classifier.classify(
            transcript: "dull one on the right, barely there, worse when I move",
            schema: schema
        )
        #expect(result["migraine_present"] == .boolean(true))
        #expect(result["severity"] == .scale(1))
        #expect(result["location"] == .choices(["right"]))
        #expect(result["quality"] == .choices(["dull"]))
        #expect(result["worse_with_movement"] == .boolean(true))
    }

    @Test func negationAndOmittedSeverity() async throws {
        let result = try await classifier.classify(
            transcript: "pounding behind my left eye, the light is killing me but no nausea",
            schema: schema
        )
        #expect(result["migraine_present"] == .boolean(true))
        if case .choices(let locations)? = result["location"] {
            #expect(Set(locations) == ["left", "behind_eye"])
        } else {
            Issue.record("Expected location choices")
        }
        #expect(result["quality"] == .choices(["throbbing"]))
        #expect(result["associated_symptoms"] == .choices(["light_sensitivity"]))
        #expect(result["severity"] == nil)
        #expect(result["bleeding"] == nil)
        #expect(result["associated_symptoms"] != .choices(["nausea"]))
    }

    @Test func synonymsAndForeignWords() async throws {
        let result = try await classifier.classify(
            transcript: "heavy period, cramps são fortes, tomei dois ibuprofeno e ajudou um pouco. dormi mal também",
            schema: schema
        )
        #expect(result["bleeding"] == .choice("heavy"))
        #expect(result["cramps_severity"] == .scale(4))
        #expect(result["relief_taken"] == .choices(["ibuprofen"]))
        #expect(result["relief_effect"] == .choice("partial"))
        #expect(result["triggers"] == .choices(["poor_sleep"]))
        #expect(result["migraine_present"] == nil)
    }

    @Test func ambiguityReturnsEmpty() async throws {
        let result = try await classifier.classify(
            transcript: "feeling rough today",
            schema: schema
        )
        #expect(result.isEmpty)
    }

    @Test func emptyTranscriptThrows() async {
        await #expect(throws: SymptomClassifierError.emptyTranscript) {
            try await classifier.classify(transcript: "   ", schema: schema)
        }
    }
}

@Suite("Classification prompt")
struct ClassificationPromptBuilderTests {
    let schema = try! SchemaConfig.load(from: .main)

    @Test func injectsAllowedFieldsFromSchema() {
        let prompt = ClassificationPromptBuilder.systemPrompt(schema: schema)
        #expect(prompt.contains("migraine_present"))
        #expect(prompt.contains("mandíbula"))
        #expect(prompt.contains("FEW-SHOT EXAMPLES"))
        #expect(!prompt.contains("[ALLOWED_FIELDS]"))
    }

    @Test func userPromptWrapsTranscript() {
        let prompt = ClassificationPromptBuilder.userPrompt(transcript: "hello")
        #expect(prompt.contains(#"User: "hello""#))
    }
}

@Suite("Classification JSON parser")
struct ClassificationJSONParserTests {
    let schema = try! SchemaConfig.load(from: .main)

    @Test func parsesBareJSON() throws {
        let result = try ClassificationJSONParser.parse(
            #"{"migraine_present": true, "severity": 2}"#,
            schema: schema
        )
        #expect(result == [
            "migraine_present": .boolean(true),
            "severity": .scale(2),
        ])
    }

    @Test func stripsCodeFencesAndValidates() throws {
        let result = try ClassificationJSONParser.parse(
            """
            ```json
            {"bleeding": "heavy", "location": ["right", "invalid"]}
            ```
            """,
            schema: schema
        )
        #expect(result == ["bleeding": .choice("heavy")])
    }
}

@Suite("Classification highlights")
struct ClassificationHighlightTests {
    @Test func mapsValuesToHighlightTokens() {
        let highlights = classificationHighlights(from: [
            "migraine_present": .boolean(true),
            "severity": .scale(1),
            "location": .choices(["right", "temple"]),
        ])
        #expect(highlights["migraine_present"] == ["true"])
        #expect(highlights["severity"] == ["1"])
        #expect(highlights["location"] == Set(["right", "temple"]))
    }
}
