import Testing
@testable import Ebb

@Suite("AppliesWhen progressive disclosure")
struct AppliesWhenTests {
    let schema = try! SchemaConfig.load(from: .main)

    @Test func fieldsWithoutHintAreAlwaysVisible() throws {
        let migraine = try #require(schema.field(forKey: "migraine_present"))
        #expect(AppliesWhenEvaluator.isVisible(field: migraine, values: [:]))
    }

    @Test func migraineSubfieldsHiddenWhenNoMigraine() throws {
        let severity = try #require(schema.field(forKey: "severity"))
        #expect(!AppliesWhenEvaluator.isVisible(field: severity, values: [:]))
        #expect(!AppliesWhenEvaluator.isVisible(field: severity, values: ["migraine_present": .boolean(false)]))
        #expect(AppliesWhenEvaluator.isVisible(field: severity, values: ["migraine_present": .boolean(true)]))
    }

    @Test func reliefEffectHiddenUntilReliefTaken() throws {
        let reliefEffect = try #require(schema.field(forKey: "relief_effect"))
        #expect(!AppliesWhenEvaluator.isVisible(field: reliefEffect, values: [:]))
        #expect(!AppliesWhenEvaluator.isVisible(field: reliefEffect, values: ["relief_taken": .choices([])]))
        #expect(AppliesWhenEvaluator.isVisible(field: reliefEffect, values: ["relief_taken": .choices(["ibuprofen"])]))
    }

    @Test func cycleFieldsAlwaysVisible() throws {
        let bleeding = try #require(schema.field(forKey: "bleeding"))
        #expect(AppliesWhenEvaluator.isVisible(field: bleeding, values: [:]))
    }
}
