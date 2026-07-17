import Foundation

/// Joins finalized speech segments and formats transcripts for display.
enum TranscriptFormatting {
    /// Appends a finalized recognition segment onto prior text, starting a new line.
    static func appendFinalizedSegment(_ segment: String, to existing: String) -> String {
        let trimmedSegment = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSegment.isEmpty else { return existing }
        let trimmedExisting = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedExisting.isEmpty else { return trimmedSegment }

        if trimmedExisting == trimmedSegment { return trimmedExisting }
        if trimmedExisting.hasSuffix("\n\(trimmedSegment)") { return trimmedExisting }
        if trimmedExisting.components(separatedBy: "\n").last == trimmedSegment { return trimmedExisting }

        let flatExisting = trimmedExisting.replacingOccurrences(of: "\n", with: " ")
        if trimmedSegment == flatExisting { return trimmedExisting }

        // Recognizer returned the full utterance-so-far on one line — grow in place.
        if trimmedSegment.hasPrefix(flatExisting) {
            let extra = String(trimmedSegment.dropFirst(flatExisting.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if extra.isEmpty { return trimmedExisting }
            if !trimmedExisting.contains("\n") {
                return trimmedSegment
            }
            return "\(trimmedExisting)\n\(extra)"
        }

        return "\(trimmedExisting)\n\(trimmedSegment)"
    }

    /// Live partial text for the segment currently being spoken.
    static func liveDisplay(segment: String, accumulated: String) -> String {
        let trimmedSegment = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSegment.isEmpty else { return accumulated }
        let trimmedExisting = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedExisting.isEmpty else { return trimmedSegment }

        let flatExisting = trimmedExisting.replacingOccurrences(of: "\n", with: " ")

        // Same utterance still growing — keep it on the current line(s).
        if trimmedSegment.hasPrefix(flatExisting) {
            if !trimmedExisting.contains("\n") {
                return trimmedSegment
            }
            let extra = String(trimmedSegment.dropFirst(flatExisting.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if extra.isEmpty { return trimmedExisting }
            return "\(trimmedExisting)\n\(extra)"
        }

        if flatExisting.contains(trimmedSegment) { return trimmedExisting }

        return "\(trimmedExisting)\n\(trimmedSegment)"
    }

    /// Display-only layout: preserve pause lines and break at commas for readability.
    /// The stored transcript stays verbatim; this is for on-screen reading only.
    static func forDisplay(_ transcript: String) -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return transcript }

        return trimmed
            .components(separatedBy: "\n")
            .map { line in
                line.replacingOccurrences(of: ", ", with: ",\n")
            }
            .joined(separator: "\n")
    }
}
