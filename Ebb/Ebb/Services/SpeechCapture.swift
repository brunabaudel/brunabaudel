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
        isListening = true

        listeningTask = Task {
            do {
                for try await partial in provider.startTranscription() {
                    guard !Task.isCancelled else { break }
                    transcript = partial
                }
            } catch {
                guard !Task.isCancelled else { return }
            }
            isListening = false
        }
    }

    func stopListening() {
        listeningTask?.cancel()
        listeningTask = nil
        isListening = false
        Task { await provider.stopTranscription() }
    }

    func resetTranscript() {
        transcript = ""
    }
}
