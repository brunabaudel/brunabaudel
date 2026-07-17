import Foundation

/// A value for one schema field, shaped by the field's `type`:
/// boolean → `.boolean`, scale → `.scale`, enum → `.choice`, multi_enum → `.choices`.
///
/// Encodes to the same JSON shape the classifier emits (`true`, `3`, `"heavy"`,
/// `["right", "temple"]`), so classifier output, persistence, and export all
/// speak one dialect.
enum FieldValue: Equatable, Sendable {
    case boolean(Bool)
    case scale(Int)
    case choice(String)
    case choices([String])
}

extension FieldValue: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Bool must be tried before Int: JSONDecoder bridges true/false to 1/0.
        if let flag = try? container.decode(Bool.self) {
            self = .boolean(flag)
        } else if let step = try? container.decode(Int.self) {
            self = .scale(step)
        } else if let key = try? container.decode(String.self) {
            self = .choice(key)
        } else if let keys = try? container.decode([String].self) {
            self = .choices(keys)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a bool, integer, string, or array of strings"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .boolean(let flag): try container.encode(flag)
        case .scale(let step): try container.encode(step)
        case .choice(let key): try container.encode(key)
        case .choices(let keys): try container.encode(keys)
        }
    }
}
