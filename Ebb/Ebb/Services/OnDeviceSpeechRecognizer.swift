import AVFoundation
import Foundation
import Speech

enum SpeechCaptureError: Error, Equatable {
    case unavailable
    case notAuthorized
    case onDeviceRecognitionUnavailable
    case localeUnsupported
    case audioEngineFailure

    var userMessage: String {
        switch self {
        case .unavailable:
            return "Speech recognition isn't available on this device."
        case .notAuthorized:
            return "Microphone or speech recognition access is off."
        case .onDeviceRecognitionUnavailable:
            return "On-device dictation for your language isn't ready. Open Settings → General → Keyboard and turn on Dictation, then try again."
        case .localeUnsupported:
            return "Speech recognition isn't available for your language on this device."
        case .audioEngineFailure:
            return "Couldn't start the microphone. Close other apps using audio and try again."
        }
    }
}

/// Forwards PCM buffers to the active recognition request on the realtime audio thread.
private final class AudioBufferSink: @unchecked Sendable {
    private let lock = NSLock()
    private weak var request: SFSpeechAudioBufferRecognitionRequest?

    func setRequest(_ request: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock()
        defer { lock.unlock() }
        self.request = request
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        request?.append(buffer)
    }
}

/// On-device `SFSpeechRecognizer` capture — audio never leaves the device.
actor OnDeviceSpeechRecognizer: SpeechRecognizerProviding {
    private let audioEngine = AVAudioEngine()
    private let audioSink = AudioBufferSink()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer: SFSpeechRecognizer?

    init(locale: Locale = .current) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    nonisolated var isAvailable: Bool {
        SFSpeechRecognizer.authorizationStatus() != .restricted
    }

    nonisolated func authorizationStatus() -> SpeechAuthStatus {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus = AVAudioApplication.shared.recordPermission

        switch speechStatus {
        case .authorized:
            switch micStatus {
            case .granted:
                return .authorized
            case .denied:
                return .denied
            case .undetermined:
                return .notDetermined
            @unknown default:
                return .notDetermined
            }
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    func requestAuthorization() async throws {
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechGranted else {
            throw SpeechCaptureError.notAuthorized
        }

        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            throw SpeechCaptureError.notAuthorized
        }
    }

    func startTranscription() async -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.runSession(continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                Task { await self.tearDownSession() }
            }
        }
    }

    func stopTranscription() async {
        await tearDownSession()
    }

    private func runSession(continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechCaptureError.localeUnsupported
        }
        guard authorizationStatus() == .authorized else {
            throw SpeechCaptureError.notAuthorized
        }
        guard speechRecognizer.supportsOnDeviceRecognition else {
            throw SpeechCaptureError.onDeviceRecognitionUnavailable
        }

        await tearDownSession()
        try configureAudioSession()
        try startAudioCapture()

        var latestText = ""
        while !Task.isCancelled {
            try beginRecognitionRequest()

            let segmentText = try await waitForRecognitionSegment(
                continuation: continuation,
                accumulated: latestText
            )
            guard !Task.isCancelled else { break }

            if !segmentText.isEmpty {
                latestText = Self.append(segmentText, to: latestText)
                continuation.yield(latestText)
            }
        }

        continuation.finish()
        await tearDownSession()
    }

    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startAudioCapture() throws {
        audioEngine.reset()

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw SpeechCaptureError.audioEngineFailure
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [audioSink] buffer, _ in
            audioSink.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            throw SpeechCaptureError.audioEngineFailure
        }
    }

    private func beginRecognitionRequest() throws {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.addsPunctuation = false
        recognitionRequest = request
        audioSink.setRequest(request)
    }

    private func waitForRecognitionSegment(
        continuation: AsyncThrowingStream<String, Error>.Continuation,
        accumulated: String
    ) async throws -> String {
        guard let speechRecognizer, let request = recognitionRequest else {
            throw SpeechCaptureError.unavailable
        }

        return try await withCheckedThrowingContinuation { segmentContinuation in
            var finished = false
            var lastPartialSegment = ""
            recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
                if let result {
                    let segment = result.bestTranscription.formattedString
                    lastPartialSegment = segment
                    let liveText = Self.liveDisplay(segment: segment, accumulated: accumulated)
                    continuation.yield(liveText)

                    if result.isFinal, !finished {
                        finished = true
                        segmentContinuation.resume(returning: segment)
                    }
                }
                if let error, !finished {
                    if Self.isBenignRecognitionError(error) {
                        finished = true
                        // Pauses often end with a benign error instead of isFinal — keep
                        // the last partial so the next utterance appends, not replaces.
                        segmentContinuation.resume(returning: lastPartialSegment)
                        return
                    }
                    finished = true
                    segmentContinuation.resume(throwing: error)
                }
            }
        }
    }

    private func tearDownSession() async {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        audioSink.setRequest(nil)

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func isBenignRecognitionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == "kAFAssistantErrorDomain" {
            switch nsError.code {
            case 1110, 209, 216, 301:
                return true
            default:
                break
            }
        }
        if nsError.domain == "kLSRErrorDomain", nsError.code == 301 {
            return true
        }
        return false
    }

    static func append(_ segment: String, to existing: String) -> String {
        let trimmedSegment = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSegment.isEmpty else { return existing }
        let trimmedExisting = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedExisting.isEmpty else { return trimmedSegment }
        if trimmedExisting == trimmedSegment || trimmedExisting.hasSuffix(" \(trimmedSegment)") {
            return trimmedExisting
        }
        return "\(trimmedExisting) \(trimmedSegment)"
    }

    static func liveDisplay(segment: String, accumulated: String) -> String {
        let trimmedSegment = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSegment.isEmpty else { return accumulated }
        return append(trimmedSegment, to: accumulated)
    }
}
