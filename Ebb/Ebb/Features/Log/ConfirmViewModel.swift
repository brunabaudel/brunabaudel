import Observation
import SwiftUI

/// Orchestrates Talk → classify → editable Confirm (Phase 6 hero flow).
@Observable
@MainActor
final class ConfirmViewModel {
    let transcript: String
    let schema: SchemaConfig

    private(set) var values: [String: FieldValue] = [:]
    private(set) var aiHighlights: [String: Set<String>] = [:]
    private(set) var isClassifying = true
    private(set) var classificationFailed = false

    private let classifier: any SymptomClassifier

    init(transcript: String, schema: SchemaConfig, classifier: any SymptomClassifier) {
        self.transcript = transcript
        self.schema = schema
        self.classifier = classifier
    }

    func classifyIfNeeded() async {
        guard isClassifying else { return }

        do {
            let classified = try await classifier.classify(transcript: transcript, schema: schema)
            applyClassification(classified)
            classificationFailed = false
        } catch SymptomClassifierError.emptyTranscript {
            classificationFailed = true
        } catch {
            // Spec: classifier failure → empty Confirm screen, never a blocking alert.
            applyClassification([:])
            classificationFailed = true
        }

        isClassifying = false
    }

    private func applyClassification(_ classified: [String: FieldValue]) {
        values = classified
        aiHighlights = classificationHighlights(from: classified)
    }
}
