import Foundation
import Testing
@testable import Ebb

@Suite("Speech capture")
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

    @Test @MainActor func deniedStatusSkipsListening() async {
        let capture = SpeechCapture(provider: MockSpeechRecognizer(status: .denied, transcript: "ignored"))
        #expect(capture.authorizationStatus == .denied)

        capture.startListening()
        #expect(capture.isListening == false)
        #expect(capture.transcript.isEmpty)
    }
}
