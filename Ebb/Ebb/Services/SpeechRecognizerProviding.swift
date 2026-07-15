import Foundation

enum SpeechAuthStatus: Equatable, Sendable {
    case unavailable
    case notDetermined
    case authorized
    case denied
}

/// On-device speech-to-text — mockable for previews, simulator, and unit tests.
protocol SpeechRecognizerProviding: Sendable {
    var isAvailable: Bool { get }
    func authorizationStatus() -> SpeechAuthStatus
    func requestAuthorization() async throws
    func startTranscription() -> AsyncThrowingStream<String, Error>
    func stopTranscription() async
}
