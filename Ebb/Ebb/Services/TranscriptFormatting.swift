import Foundation

/// Joins finalized speech segments with line breaks so Talk shows each utterance on its own line.
enum TranscriptFormatting {
    /// Appends a finalized recognition segment onto prior text, starting a new line.
    static func appendFinalizedSegment(_ segment: String, to existing: String) -> String {
        let trimmedSegment = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSegment.isEmpty else { return existing }
        let trimmedExisting = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedExisting.isEmpty else { return trimmedSegment }
        return "\(trimmedExisting)\n\(trimmedSegment)"
    }

    /// Live partial text for the segment currently being spoken.
    static func liveDisplay(segment: String, accumulated: String) -> String {
        let trimmedSegment = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSegment.isEmpty else { return accumulated }
        let trimmedExisting = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedExisting.isEmpty else { return trimmedSegment }
        return "\(trimmedExisting)\n\(trimmedSegment)"
    }
}
