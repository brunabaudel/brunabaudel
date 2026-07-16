import Foundation
import SwiftUI

/// Maps a verbatim transcript onto schema-valid field values (build-plan
/// `SymptomClassifier`). Apple Foundation Models and the synonym fallback are
/// swappable behind this seam.
protocol SymptomClassifier: Sendable {
    /// Human-readable backend name for Settings/debug surfaces.
    var providerName: String { get }

    func classify(transcript: String, schema: SchemaConfig) async throws -> [String: FieldValue]
}

enum SymptomClassifierError: Error, Equatable {
    case emptyTranscript
    case modelUnavailable
    case invalidModelResponse
}

enum SymptomClassifierFactory {
    static func makeDefault() -> any SymptomClassifier {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let apple = AppleFoundationModelsClassifier()
            if apple.isAvailable {
                return apple
            }
        }
        #endif
        return SynonymSymptomClassifier()
    }

    static func makeForTests() -> any SymptomClassifier {
        SynonymSymptomClassifier()
    }
}

extension FieldValue {
    /// Tokens used by `SchemaFormView` / `FieldControl` to glow AI-filled pills.
    var highlightTokens: Set<String> {
        switch self {
        case .boolean(let flag):
            return [flag ? "true" : "false"]
        case .scale(let step):
            return ["\(step)"]
        case .choice(let key):
            return [key]
        case .choices(let keys):
            return Set(keys)
        }
    }
}

func classificationHighlights(from values: [String: FieldValue]) -> [String: Set<String>] {
    values.mapValues(\.highlightTokens)
}

// MARK: - Environment

private final class SymptomClassifierBox: @unchecked Sendable {
    let classifier: any SymptomClassifier
    init(_ classifier: any SymptomClassifier) { self.classifier = classifier }
}

private enum SymptomClassifierEnvironmentKey: EnvironmentKey {
    static let defaultValue = SymptomClassifierBox(SynonymSymptomClassifier())
}

extension EnvironmentValues {
    var symptomClassifier: any SymptomClassifier {
        get { self[SymptomClassifierEnvironmentKey.self].classifier }
        set { self[SymptomClassifierEnvironmentKey.self] = SymptomClassifierBox(newValue) }
    }
}
