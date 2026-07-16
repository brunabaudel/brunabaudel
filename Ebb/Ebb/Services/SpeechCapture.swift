import Foundation
import Observation
import Speech

/// On-device speech-to-text stream (build-plan `SpeechCapture`).
@Observable
@MainActor
final class SpeechCapture {
    private(set) var authorizationStatus: SpeechAuthStatus = .unavailable
    private(set) var transcript: String = ""
    private(set) var isListening: Bool = false
    private(set) var listeningError: String?

    private let provider: any SpeechRecognizerProviding
    private var listeningTask: Task<Void, Never>?

    init(provider: (any SpeechRecognizerProviding)? = nil) {
        if let provider {
            self.provider = provider
        } else if let mockText = ProcessInfo.processInfo.mockTranscriptText {
            self.provider = MockSpeechRecognizer(transcript: mockText)
        } else if SFSpeechRecognizer.authorizationStatus() == .restricted {
            self.provider = MockSpeechRecognizer(status: .unavailable, transcript: "")
        } else {
            self.provider = OnDeviceSpeechRecognizer()
        }
        authorizationStatus = self.provider.authorizationStatus()
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = provider.authorizationStatus()
    }

    func requestAuthorization() async {
        guard provider.isAvailable else {
            authorizationStatus = .unavailable
            return
        }

        do {
            try await provider.requestAuthorization()
            authorizationStatus = provider.authorizationStatus()
        } catch {
            authorizationStatus = provider.authorizationStatus()
        }
    }

    func startListening() {
        guard authorizationStatus == .authorized else { return }
        stopListening()

        transcript = ""
        listeningError = nil
        isListening = true

        let provider = provider
        listeningTask = Task {
            do {
                let stream = await provider.startTranscription()
                for try await partial in stream {
                    guard !Task.isCancelled else { break }
                    applyPartialTranscript(partial)
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                applyListeningError(Self.userMessage(for: error))
            }
            isListening = false
        }
    }

    func stopListening() {
        listeningTask?.cancel()
        listeningTask = nil
        isListening = false
        let provider = provider
        Task { await provider.stopTranscription() }
    }

    func resetTranscript() {
        transcript = ""
        listeningError = nil
    }

    private func applyPartialTranscript(_ partial: String) {
        transcript = partial
        listeningError = nil
    }

    private func applyListeningError(_ message: String) {
        listeningError = message
    }

    private static func userMessage(for error: Error) -> String {
        if let captureError = error as? SpeechCaptureError {
            return captureError.userMessage
        }
        return "Couldn't capture speech. Try again or use Tap instead."
    }
}
