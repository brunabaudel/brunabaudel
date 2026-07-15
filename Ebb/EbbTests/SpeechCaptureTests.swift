import Foundation
import Testing
@testable import Ebb

@Suite("Speech capture")
struct SpeechCaptureTests {
    @Test @MainActor func mockRecognizerStreamsTranscript() async throws {
        let capture = SpeechCapture(provider: MockSpeechRecognizer(
            transcript: "dull one on the right",
            chunkDelayNanoseconds: 10_000_000
        ))
        capture.startListening()

        try await Task.sleep(for: .milliseconds(500))
        capture.stopListening()

        #expect(capture.transcript == "dull one on the right")
    }

    @Test @MainActor func deniedStatusSkipsListening() async {
        let capture = SpeechCapture(provider: MockSpeechRecognizer(status: .denied, transcript: "ignored"))
        #expect(capture.authorizationStatus == .denied)

        capture.startListening()
        #expect(capture.isListening == false)
        #expect(capture.transcript.isEmpty)
    }
}
