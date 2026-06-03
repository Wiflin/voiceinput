import AppKit
import Foundation

@MainActor
final class DictationController {
    private enum State {
        case idle
        case recording(TriggerKey)
        case refining
        case injecting
    }

    private let settings: AppSettings
    private let panel = FloatingTranscriptPanel()
    private let transcriber = SpeechTranscriber()
    private let injector = TextInjector()
    private let refiner = LLMRefiner()
    private var hotkeyMonitor: GlobalHotkeyMonitor?
    private var state: State = .idle
    private var latestTranscript = ""
    private var recordingTask: Task<Void, Never>?
    private var recordingGeneration = 0
    private var optionReleaseTimer: Timer?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func startMonitoringHotkeys() {
        hotkeyMonitor = GlobalHotkeyMonitor(
            onDown: { [weak self] key in
                DispatchQueue.main.async { self?.startRecording(trigger: key) }
            },
            onUp: { [weak self] key in
                DispatchQueue.main.async { self?.finishRecording(trigger: key) }
            }
        )

        if hotkeyMonitor?.start() == false {
            panel.showStatus("Enable Accessibility permission for VoiceInput")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [panel] in
                panel.hide()
            }
        }
    }

    func languageDidChange() {
        if case .recording = state {
            Task { await stopTranscriber() }
            startRecording(trigger: .option)
        }
    }

    private func startRecording(trigger: TriggerKey) {
        guard case .idle = state else { return }

        latestTranscript = ""
        state = .recording(trigger)
        recordingGeneration += 1
        let generation = recordingGeneration
        recordingTask?.cancel()
        panel.showListening()
        startOptionReleaseWatchdog(generation: generation)

        let localeIdentifier = settings.language.rawValue
        let inputDeviceUID = settings.inputDeviceUID

        recordingTask = Task {
            do {
                guard !Task.isCancelled else { return }
                try await transcriber.start(
                    localeIdentifier: localeIdentifier,
                    inputDeviceUID: inputDeviceUID,
                    onTranscript: { [weak self] text in
                        DispatchQueue.main.async {
                            self?.handleTranscript(text, generation: generation)
                        }
                    },
                    onLevel: { [weak self] level in
                        DispatchQueue.main.async {
                            self?.handleLevel(level, generation: generation)
                        }
                    }
                )
                if Task.isCancelled {
                    _ = await transcriber.stop()
                }
            } catch {
                await MainActor.run {
                    guard self.recordingGeneration == generation else { return }
                    NSLog("VoiceInput recording failed: \(String(describing: error))")
                    self.latestTranscript = ""
                    self.panel.showStatus(self.statusMessage(for: error))
                    self.state = .idle
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [panel] in
                        panel.hide()
                    }
                }
            }
        }
    }

    private func finishRecording(trigger: TriggerKey) {
        guard case .recording(let activeTrigger) = state, activeTrigger == trigger else { return }
        state = .refining
        recordingGeneration += 1
        recordingTask?.cancel()
        recordingTask = nil
        stopOptionReleaseWatchdog()

        Task {
            let rawText = await stopTranscriber().trimmingCharacters(in: .whitespacesAndNewlines)
            await MainActor.run {
                latestTranscript = rawText
            }

            guard !rawText.isEmpty else {
                await MainActor.run {
                    state = .idle
                    panel.hide()
                }
                return
            }

            let finalText: String
            if settings.llmEnabled && settings.isLLMConfigured {
                await MainActor.run {
                    panel.showStatus("Refining...")
                }
                finalText = await refiner.refine(
                    text: rawText,
                    baseURL: settings.apiBaseURL,
                    apiKey: settings.apiKey,
                    model: settings.model
                )
            } else {
                finalText = rawText
            }

            await MainActor.run {
                state = .injecting
                panel.updateTranscript(finalText)
                injector.inject(finalText) { [weak self] in
                    self?.state = .idle
                    self?.panel.hide()
                }
            }
        }
    }

    private func stopTranscriber() async -> String {
        await transcriber.stop()
    }

    private func statusMessage(for error: Error) -> String {
        if let deviceError = error as? AudioInputDeviceManager.DeviceError {
            switch deviceError {
            case .unavailable:
                return "Selected microphone unavailable"
            case .audioUnitUnavailable, .selectionFailed:
                return "Unable to select microphone"
            }
        }

        if let transcriptionError = error as? SpeechTranscriber.TranscriptionError {
            switch transcriptionError {
            case .speechNotAuthorized:
                return "Enable Speech Recognition permission"
            case .recognizerUnavailable:
                return "Speech recognizer unavailable"
            }
        }

        if (error as NSError).domain == "com.apple.coreaudio.avfaudio" {
            return "Unable to start microphone"
        }

        return "Speech recognition unavailable"
    }

    private func handleTranscript(_ text: String, generation: Int) {
        guard recordingGeneration == generation else { return }
        latestTranscript = text
        panel.updateTranscript(text)
    }

    private func handleLevel(_ level: Double, generation: Int) {
        guard recordingGeneration == generation else { return }
        panel.updateLevel(level)
    }

    private func startOptionReleaseWatchdog(generation: Int) {
        stopOptionReleaseWatchdog()

        let timer = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard
                    let self,
                    self.recordingGeneration == generation,
                    case .recording(.option) = self.state
                else { return }

                let flags = CGEventSource.flagsState(.combinedSessionState)
                if !flags.contains(.maskAlternate) {
                    self.finishRecording(trigger: .option)
                }
            }
        }

        optionReleaseTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopOptionReleaseWatchdog() {
        optionReleaseTimer?.invalidate()
        optionReleaseTimer = nil
    }
}
