import Foundation

/// Simulates Talk with a pause between phrases — each yield is the full cumulative
/// transcript, as `OnDeviceSpeechRecognizer` produces after a segment ends.
struct PausingMockSpeechRecognizer: SpeechRecognizerProviding {
    var isAvailable: Bool { true }

    func authorizationStatus() -> SpeechAuthStatus { .authorized }

    func requestAuthorization() async throws {}

    func startTranscription() async -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                continuation.yield("dull one")
                try await Task.sleep(nanoseconds: 80_000_000)
                continuation.yield("dull one on the right")
                try await Task.sleep(nanoseconds: 80_000_000)
                continuation.yield("dull one on the right barely there")
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func stopTranscription() async {}
}
