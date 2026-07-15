import AVFoundation
import Foundation
import Speech

enum SpeechCaptureError: Error, Equatable {
    case unavailable
    case notAuthorized
    case onDeviceRecognitionUnavailable
}

/// On-device `SFSpeechRecognizer` capture — audio never leaves the device.
actor OnDeviceSpeechRecognizer: SpeechRecognizerProviding {
    private let audioEngine = AVAudioEngine()
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
                    try await self.runRecognition(continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                Task { await self.tearDownRecognition() }
            }
        }
    }

    func stopTranscription() async {
        await tearDownRecognition()
    }

    private func runRecognition(continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechCaptureError.unavailable
        }
        guard authorizationStatus() == .authorized else {
            throw SpeechCaptureError.notAuthorized
        }
        guard speechRecognizer.supportsOnDeviceRecognition else {
            throw SpeechCaptureError.onDeviceRecognitionUnavailable
        }

        await tearDownRecognition()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
            if let result {
                continuation.yield(result.bestTranscription.formattedString)
                if result.isFinal {
                    continuation.finish()
                    Task { await self.tearDownRecognition() }
                }
            }
            if let error {
                continuation.finish(throwing: error)
                Task { await self.tearDownRecognition() }
            }
        }
    }

    private func tearDownRecognition() async {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
