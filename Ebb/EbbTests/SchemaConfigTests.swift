import Foundation
import Testing
@testable import Ebb

@Suite("Schema loading")
struct SchemaLoadingTests {
    // Tests are hosted in the app, so Bundle.main is the Ebb bundle —
    // the exact resource the release app loads.
    let schema = try! SchemaConfig.load(from: .main)

    @Test func bundledSchemaDecodes() {
        #expect(schema.schemaVersion == "0.1.0")
        #expect(schema.domain == "menstrual-migraine-and-period")
        #expect(schema.fields.count == 13)
    }

    @Test func fieldShapesMatchTheSpec() throws {
        let severity = try #require(schema.field(forKey: "severity"))
        #expect(severity.type == .scale)
        #expect(severity.range == 1...5)
        #expect(severity.scaleLabels[1] == "barely there")
        #expect(severity.scaleLabels[5] == "disabling")
        #expect(severity.appliesWhen == "migraine_present == true")

        let cramps = try #require(schema.field(forKey: "cramps_severity"))
        #expect(cramps.range == 0...5)

        let migraine = try #require(schema.field(forKey: "migraine_present"))
        #expect(migraine.type == .boolean)
        #expect(migraine.isRequired)

        let bleeding = try #require(schema.field(forKey: "bleeding"))
        #expect(bleeding.type == .singleEnum)
        #expect(bleeding.allowedValueKeys == ["none", "spotting", "light", "medium", "heavy"])

        let location = try #require(schema.field(forKey: "location"))
        #expect(location.type == .multiEnum)
        #expect(location.allowedValueKeys.contains("behind_eye"))
    }

    @Test func synonymsAreCarriedForTheClassifier() throws {
        let location = try #require(schema.field(forKey: "location"))
        let jaw = try #require(location.values.first { $0.key == "jaw" })
        #expect(jaw.synonyms.contains("mandíbula"))
    }

    @Test func missingResourceThrows() {
        #expect(throws: SchemaConfig.LoadError.resourceNotFound("symptom-schema.json")) {
            try SchemaConfig.load(from: Bundle(for: BundleToken.self))
        }
    }
}

/// The test bundle itself contains no schema resource, which makes it the
/// negative case for `load(from:)`.
private final class BundleToken {}

@Suite("Validation gate")
struct ValidationGateTests {
    let schema = try! SchemaConfig.load(from: .main)

    @Test func keepsSchemaValidValues() {
        let input: [String: FieldValue] = [
            "migraine_present": .boolean(true),
            "severity": .scale(4),
            "bleeding": .choice("heavy"),
            "location": .choices(["right", "behind_eye"]),
        ]
        #expect(schema.validated(input) == input)
    }

    @Test func dropsUnknownFieldKeys() {
        let result = schema.validated(["mood": .choice("great")])
        #expect(result.isEmpty)
    }

    @Test func dropsOffMenuEnumValues() {
        #expect(schema.validated(["bleeding": .choice("torrential")]).isEmpty)
    }

    @Test func filtersOffMenuChoicesButKeepsValidOnes() {
        let result = schema.validated(["location": .choices(["right", "elbow"])])
        #expect(result == ["location": .choices(["right"])])
    }

    @Test func dropsMultiEnumWhenNothingSurvives() {
        #expect(schema.validated(["location": .choices(["elbow"])]).isEmpty)
    }

    @Test func deduplicatesChoicesPreservingOrder() {
        let result = schema.validated(["quality": .choices(["dull", "sharp", "dull"])])
        #expect(result == ["quality": .choices(["dull", "sharp"])])
    }

    @Test func dropsOutOfRangeScales() {
        #expect(schema.validated(["severity": .scale(0)]).isEmpty)
        #expect(schema.validated(["severity": .scale(6)]).isEmpty)
        #expect(schema.validated(["cramps_severity": .scale(0)]) == ["cramps_severity": .scale(0)])
    }

    @Test func dropsTypeMismatches() {
        #expect(schema.validated(["migraine_present": .scale(1)]).isEmpty)
        #expect(schema.validated(["severity": .boolean(true)]).isEmpty)
        #expect(schema.validated(["location": .choice("right")]).isEmpty)
        #expect(schema.validated(["bleeding": .choices(["light"])]).isEmpty)
    }

    @Test func emptyInputStaysEmpty() {
        // Spec rule 7: {} is a valid, correct classifier answer.
        #expect(schema.validated([:]).isEmpty)
    }
}
