import Foundation
import Testing
@testable import Ebb

@Suite("Speech capture", .serialized)
struct SpeechCaptureTests {
    @Test @MainActor func mockRecognizerStreamsTranscript() async throws {
        let capture = SpeechCapture(provider: MockSpeechRecognizer(
            transcript: "dull one on the right",
            chunkDelayNanoseconds: 5_000_000
        ))
        capture.startListening()

        for _ in 0 ..< 100 {
            if capture.transcript == "dull one on the right" {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }

        capture.stopListening()
        #expect(capture.transcript == "dull one on the right")
    }

    @Test @MainActor func appendsAcrossPausesWithoutClearing() async throws {
        let capture = SpeechCapture(provider: PausingMockSpeechRecognizer())
        capture.startListening()

        for _ in 0 ..< 100 {
            if capture.transcript == "dull one on the right barely there" {
                break
            }
            try await Task.sleep(for: .milliseconds(50))
        }

        capture.stopListening()
        #expect(capture.transcript == "dull one on the right barely there")
    }

    @Test @MainActor func ignoresEmptyPartialHeartbeats() async throws {
        struct HeartbeatRecognizer: SpeechRecognizerProviding {
            var isAvailable: Bool { true }
            func authorizationStatus() -> SpeechAuthStatus { .authorized }
            func requestAuthorization() async throws {}
            func startTranscription() async -> AsyncThrowingStream<String, Error> {
                AsyncThrowingStream { continuation in
                    Task {
                        continuation.yield("hello")
                        try await Task.sleep(nanoseconds: 20_000_000)
                        continuation.yield("")
                        try await Task.sleep(nanoseconds: 20_000_000)
                        continuation.yield("hello world")
                        continuation.finish()
                    }
                }
            }
            func stopTranscription() async {}
        }

        let capture = SpeechCapture(provider: HeartbeatRecognizer())
        capture.startListening()

        for _ in 0 ..< 100 {
            if capture.transcript == "hello world" { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        capture.stopListening()
        #expect(capture.transcript == "hello world")
    }

    @Test @MainActor func deniedStatusSkipsListening() async {
        let capture = SpeechCapture(provider: MockSpeechRecognizer(status: .denied, transcript: "ignored"))
        #expect(capture.authorizationStatus == .denied)

        capture.startListening()
        #expect(capture.isListening == false)
        #expect(capture.transcript.isEmpty)
    }

    @Test @MainActor func surfacesRecognitionErrors() async {
        struct FailingRecognizer: SpeechRecognizerProviding {
            var isAvailable: Bool { true }
            func authorizationStatus() -> SpeechAuthStatus { .authorized }
            func requestAuthorization() async throws {}
            func startTranscription() async -> AsyncThrowingStream<String, Error> {
                AsyncThrowingStream { continuation in
                    continuation.finish(throwing: SpeechCaptureError.onDeviceRecognitionUnavailable)
                }
            }
            func stopTranscription() async {}
        }

        let capture = SpeechCapture(provider: FailingRecognizer())
        capture.startListening()
        try? await Task.sleep(for: .milliseconds(100))
        #expect(capture.listeningError != nil)
        #expect(capture.isListening == false)
    }
}

@Suite("Transcript assembly")
struct TranscriptAssemblyTests {
    @Test func appendJoinsSegmentsWithLineBreak() {
        #expect(TranscriptFormatting.appendFinalizedSegment("world", to: "hello") == "hello\nworld")
    }

    @Test func appendSkipsDuplicateSuffix() {
        #expect(TranscriptFormatting.appendFinalizedSegment("world", to: "hello\nworld") == "hello\nworld")
    }

    @Test func liveDisplayCombinesAccumulatedAndPartial() {
        #expect(
            TranscriptFormatting.liveDisplay(segment: "on the right", accumulated: "dull one")
                == "dull one\non the right"
        )
    }

    @Test func liveDisplayKeepsGrowingUtteranceOnOneLine() {
        #expect(
            TranscriptFormatting.liveDisplay(
                segment: "dull one on the right",
                accumulated: "dull one"
            ) == "dull one on the right"
        )
    }
}
