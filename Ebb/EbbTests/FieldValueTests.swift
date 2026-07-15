import Foundation
import Testing
@testable import Ebb

@Suite("FieldValue JSON dialect")
struct FieldValueTests {
    @Test func decodesTheClassifierOutputShape() throws {
        // The exact shape of few-shot example 1 in the classification spec.
        let json = Data("""
        {
          "migraine_present": true,
          "severity": 1,
          "location": ["right"],
          "quality": ["dull"],
          "worse_with_movement": true,
          "bleeding": "light"
        }
        """.utf8)

        let decoded = try JSONDecoder().decode([String: FieldValue].self, from: json)
        #expect(decoded["migraine_present"] == .boolean(true))
        #expect(decoded["severity"] == .scale(1))
        #expect(decoded["location"] == .choices(["right"]))
        #expect(decoded["worse_with_movement"] == .boolean(true))
        #expect(decoded["bleeding"] == .choice("light"))
    }

    @Test func booleansDoNotDecodeAsIntegers() throws {
        let decoded = try JSONDecoder().decode([String: FieldValue].self, from: Data(#"{"a": true, "b": 1}"#.utf8))
        #expect(decoded["a"] == .boolean(true))
        #expect(decoded["b"] == .scale(1))
    }

    @Test(arguments: [
        FieldValue.boolean(false),
        .scale(5),
        .choice("heavy"),
        .choices(["right", "temple"]),
        .choices([]),
    ])
    func roundTripsThroughJSON(value: FieldValue) throws {
        let data = try JSONEncoder().encode(["key": value])
        let decoded = try JSONDecoder().decode([String: FieldValue].self, from: data)
        #expect(decoded["key"] == value)
    }
}
