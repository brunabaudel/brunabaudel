import Testing
@testable import Ebb

@Suite("Transcript formatting")
struct TranscriptFormattingTests {
    @Test func firstSegmentHasNoLeadingNewline() {
        #expect(TranscriptFormatting.appendFinalizedSegment("hello", to: "") == "hello")
        #expect(TranscriptFormatting.liveDisplay(segment: "hello", accumulated: "") == "hello")
    }

    @Test func finalizedSegmentsJoinWithLineBreaks() {
        let first = TranscriptFormatting.appendFinalizedSegment("dull one on the right", to: "")
        let combined = TranscriptFormatting.appendFinalizedSegment("worse when I move", to: first)
        #expect(combined == "dull one on the right\nworse when I move")
    }

    @Test func liveDisplayStartsNewLineAfterAccumulatedText() {
        let accumulated = "dull one on the right"
        #expect(
            TranscriptFormatting.liveDisplay(segment: "worse", accumulated: accumulated)
                == "dull one on the right\nworse"
        )
    }

    @Test func appendSkipsDuplicateSuffix() {
        #expect(TranscriptFormatting.appendFinalizedSegment("world", to: "hello\nworld") == "hello\nworld")
    }

    @Test func appendGrowsSingleLineWhenRecognizerReturnsCumulativeText() {
        #expect(
            TranscriptFormatting.appendFinalizedSegment(
                "dull one on the right",
                to: "dull one"
            ) == "dull one on the right"
        )
    }

    @Test func liveDisplayGrowsSingleLineWhenRecognizerReturnsCumulativePartial() {
        #expect(
            TranscriptFormatting.liveDisplay(
                segment: "dull one on the right",
                accumulated: "dull one"
            ) == "dull one on the right"
        )
    }

    @Test func forDisplayBreaksAtCommasAndPreservesPauseLines() {
        let raw = "dull one on the right, barely there\nworse when I move"
        #expect(
            TranscriptFormatting.forDisplay(raw)
                == "dull one on the right,\nbarely there\nworse when I move"
        )
    }

    @Test func emptySegmentsAreIgnored() {
        #expect(TranscriptFormatting.appendFinalizedSegment("   ", to: "hello") == "hello")
        #expect(TranscriptFormatting.liveDisplay(segment: "  ", accumulated: "hello") == "hello")
    }
}
