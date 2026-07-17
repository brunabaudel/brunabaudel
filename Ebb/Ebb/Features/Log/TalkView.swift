import SwiftUI

/// Voice capture surface — dim, near-empty, breathing orb, live transcript.
/// Transcription only; classification runs on the Confirm screen (Phase 6).
struct TalkView: View {
    let schema: SchemaConfig
    var onFinish: (String) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SpeechCapture.self) private var speechCapture

    @State private var permissionPhase: PermissionPhase = .checking

    private enum PermissionPhase {
        case checking
        case denied
        case ready
    }

    var body: some View {
        NavigationStack {
            Group {
                switch permissionPhase {
                case .checking:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .denied:
                    permissionDeniedContent
                case .ready:
                    listeningContent
                }
            }
            .background(theme.base)
            .foregroundStyle(theme.text)
            .navigationTitle("Talk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { close() }
                }
                if permissionPhase == .ready {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { finish() }
                            .disabled(speechCapture.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .task {
                await preparePermissions()
            }
            .onDisappear {
                speechCapture.stopListening()
            }
        }
    }

    private var listeningContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)

            Text("Tell me how you feel.")
                .font(.system(.title2, design: .serif))
                .multilineTextAlignment(.center)

            Text("However it comes out — I'll sort it into the chart.")
                .font(.footnote)
                .foregroundStyle(theme.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 24)

            Spacer(minLength: 28)

            TalkOrb(isAnimating: speechCapture.isListening, reduceMotion: reduceMotion)
                .padding(.bottom, 18)

            TalkWaveBars(isAnimating: speechCapture.isListening, reduceMotion: reduceMotion)
                .padding(.bottom, 32)

            LiveTranscriptCard(
                transcript: speechCapture.transcript,
                isListening: speechCapture.isListening,
                errorMessage: speechCapture.listeningError
            )
            .padding(.horizontal, 20)

            if speechCapture.listeningError != nil {
                Button("Try again") {
                    speechCapture.startListening()
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.pain)
                .padding(.top, 16)
            }

            Spacer(minLength: 24)
        }
    }

    private var permissionDeniedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()

            Label("Microphone access is off", systemImage: "mic.slash.fill")
                .font(.headline)
                .foregroundStyle(theme.pain)

            Text("Ebb needs the microphone so you can say how you feel. Recognition stays on this device — nothing is sent to a server.")
                .font(.subheadline)
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Text("You can still log with Tap on Today.")
                .font(.subheadline)
                .foregroundStyle(theme.text)

            Button("Use Tap instead") { close() }
                .buttonStyle(.borderedProminent)
                .tint(theme.pain)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            Spacer()
        }
        .padding(24)
    }

    private func preparePermissions() async {
        speechCapture.refreshAuthorizationStatus()

        switch speechCapture.authorizationStatus {
        case .authorized:
            permissionPhase = .ready
            speechCapture.startListening()
        case .notDetermined:
            await speechCapture.requestAuthorization()
            speechCapture.refreshAuthorizationStatus()
            if speechCapture.authorizationStatus == .authorized {
                permissionPhase = .ready
                speechCapture.startListening()
            } else {
                permissionPhase = .denied
            }
        case .denied, .unavailable:
            permissionPhase = .denied
        }
    }

    private func finish() {
        let text = speechCapture.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        speechCapture.stopListening()
        dismiss()
        onFinish(text)
    }

    private func close() {
        speechCapture.stopListening()
        dismiss()
    }
}

// MARK: - Orb

private struct TalkOrb: View {
    let isAnimating: Bool
    let reduceMotion: Bool

    @Environment(\.theme) private var theme
    @State private var breathe = false

    var body: some View {
        ZStack {
            if isAnimating && !reduceMotion {
                Circle()
                    .stroke(theme.pain.opacity(0.35), lineWidth: 2)
                    .frame(width: 168, height: 168)
                    .scaleEffect(breathe ? 1.08 : 0.94)
                    .opacity(breathe ? 0.35 : 0.75)
                    .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: breathe)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [theme.pain, theme.painDim],
                        center: .center,
                        startRadius: 8,
                        endRadius: 74
                    )
                )
                .frame(width: 148, height: 148)
                .overlay {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(theme.onPain)
                }
                .accessibilityLabel(isAnimating ? "Listening" : "Microphone")
        }
        .onAppear {
            if isAnimating && !reduceMotion {
                breathe = true
            }
        }
        .onChange(of: isAnimating) { _, listening in
            breathe = listening && !reduceMotion
        }
    }
}

// MARK: - Wave bars

private struct TalkWaveBars: View {
    let isAnimating: Bool
    let reduceMotion: Bool

    @Environment(\.theme) private var theme

    private let barHeights: [CGFloat] = [10, 18, 26, 14, 30, 16, 22]

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            ForEach(barHeights.indices, id: \.self) { index in
                TalkWaveBar(
                    baseHeight: barHeights[index],
                    isAnimating: isAnimating,
                    reduceMotion: reduceMotion,
                    delay: Double(index) * 0.08
                )
                .foregroundStyle(theme.pain)
            }
        }
        .frame(height: 34)
        .accessibilityHidden(true)
    }
}

private struct TalkWaveBar: View {
    let baseHeight: CGFloat
    let isAnimating: Bool
    let reduceMotion: Bool
    let delay: Double

    @State private var expanded = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .frame(width: 4, height: expanded ? baseHeight + 8 : baseHeight)
            .animation(
                isAnimating && !reduceMotion
                    ? .easeInOut(duration: 0.55).repeatForever(autoreverses: true).delay(delay)
                    : .default,
                value: expanded
            )
            .onAppear {
                expanded = isAnimating && !reduceMotion
            }
            .onChange(of: isAnimating) { _, listening in
                expanded = listening && !reduceMotion
            }
    }
}

// MARK: - Live transcript

private struct LiveTranscriptCard: View {
    let transcript: String
    let isListening: Bool
    var errorMessage: String?

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var statusLabel: String {
        if errorMessage != nil {
            return "Couldn't listen"
        }
        return isListening ? "Listening" : "Paused"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(statusLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(errorMessage == nil ? theme.pain : theme.muted)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.painDim, in: Capsule())

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                        Text(displayText)
                            .font(.body.monospaced())
                            .foregroundStyle(theme.text)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .id("transcript-body")

                        if isListening && !reduceMotion {
                            BlinkingCursor()
                                .foregroundStyle(theme.pain)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .onChange(of: transcript) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("transcript-body", anchor: .bottom)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(theme.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Live transcript. \(transcript)")
    }

    private var displayText: String {
        if transcript.isEmpty {
            return "Start speaking when you're ready…"
        }
        return TranscriptFormatting.forDisplay(transcript)
    }
}

private struct BlinkingCursor: View {
    @State private var visible = true

    var body: some View {
        Text("|")
            .font(.body.monospaced())
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    visible.toggle()
                }
            }
    }
}

#Preview("Listening") {
    let capture = SpeechCapture(provider: MockSpeechRecognizer(
        transcript: "dull one on the right, barely there"
    ))
    capture.startListening()
    return TalkView(schema: try! SchemaConfig.load()) { _ in }
        .environment(\.theme, .plumEmber)
        .environment(capture)
}

#Preview("Denied") {
    TalkView(schema: try! SchemaConfig.load()) { _ in }
        .environment(\.theme, .plumEmber)
        .environment(SpeechCapture(provider: MockSpeechRecognizer(status: .denied, transcript: "")))
}
