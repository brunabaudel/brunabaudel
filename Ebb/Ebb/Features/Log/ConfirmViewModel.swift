import Observation
import SwiftUI

/// Orchestrates Talk → classify → editable Confirm (Phase 6 hero flow).
@Observable
@MainActor
final class ConfirmViewModel {
    let transcript: String
    let schema: SchemaConfig

    /// Editable field values — user can fix AI pre-fills before saving.
    var values: [String: FieldValue] = [:]
    private(set) var aiHighlights: [String: Set<String>] = [:]
    private(set) var isClassifying = true
    private(set) var classificationFailed = false

    private let classifier: any SymptomClassifier
    private let medicationPreferences: MedicationPreferences?

    init(
        transcript: String,
        schema: SchemaConfig,
        classifier: any SymptomClassifier,
        medicationPreferences: MedicationPreferences? = nil
    ) {
        self.transcript = transcript
        self.schema = schema
        self.classifier = classifier
        self.medicationPreferences = medicationPreferences
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
        var merged = classified
        applyMedicationPrefill(to: &merged)
        values = merged
        aiHighlights = classificationHighlights(from: classified)
    }

    private func applyMedicationPrefill(to values: inout [String: FieldValue]) {
        guard let medicationPreferences else { return }
        let allowed = schema.field(forKey: "relief_taken")?.allowedValueKeys ?? []
        let saved = medicationPreferences.savedReliefKeys.filter { allowed.contains($0) }
        guard !saved.isEmpty else { return }

        switch values["relief_taken"] {
        case nil:
            values["relief_taken"] = .choices(saved)
        case .choices(let existing) where existing.isEmpty:
            values["relief_taken"] = .choices(saved)
        default:
            break
        }
    }
}
