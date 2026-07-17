import Foundation

/// Deterministic classifier for previews and unit tests.
struct MockSymptomClassifier: SymptomClassifier {
    let providerName: String
    private let handler: @Sendable (String, SchemaConfig) async throws -> [String: FieldValue]

    init(
        providerName: String = "Mock",
        handler: @escaping @Sendable (String, SchemaConfig) async throws -> [String: FieldValue]
    ) {
        self.providerName = providerName
        self.handler = handler
    }

    init(fixedValues: [String: FieldValue], providerName: String = "Mock") {
        self.init(providerName: providerName) { _, schema in
            schema.validated(fixedValues)
        }
    }

    func classify(transcript: String, schema: SchemaConfig) async throws -> [String: FieldValue] {
        try await handler(transcript, schema)
    }
}
