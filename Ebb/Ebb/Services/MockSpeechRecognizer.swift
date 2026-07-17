import Foundation

/// Streams a canned transcript for previews, CI screenshots, and unit tests.
struct MockSpeechRecognizer: SpeechRecognizerProviding {
    var isAvailable: Bool = true
    var status: SpeechAuthStatus = .authorized
    var transcript: String
    var chunkDelayNanoseconds: UInt64 = 120_000_000

    func authorizationStatus() -> SpeechAuthStatus { status }

    func requestAuthorization() async throws {}

    func startTranscription() async -> AsyncThrowingStream<String, Error> {
        let words = transcript.split(separator: " ").map(String.init)
        return AsyncThrowingStream { continuation in
            let task = Task {
                var accumulated = ""
                for (index, word) in words.enumerated() {
                    try Task.checkCancellation()
                    if index == 0 {
                        accumulated = word
                    } else {
                        accumulated += " \(word)"
                    }
                    continuation.yield(accumulated)
                    try await Task.sleep(nanoseconds: chunkDelayNanoseconds)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func stopTranscription() async {}
}
