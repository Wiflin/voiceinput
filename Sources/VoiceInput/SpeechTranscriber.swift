import AVFoundation
import Foundation
import QuartzCore
import Speech

actor SpeechTranscriber {
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var transcriptState = TranscriptState()
    private let recognitionGain: Float = 1.9

    func start(
        localeIdentifier: String,
        inputDeviceUID: String?,
        onTranscript: @escaping @Sendable (String) -> Void,
        onLevel: @escaping @Sendable (Double) -> Void
    ) async throws {
        _ = await stop()

        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw TranscriptionError.speechNotAuthorized
        }

        let locale = Locale(identifier: localeIdentifier)
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        let engine = AVAudioEngine()
        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation

        let levelThrottle = AudioLevelThrottle(maxFramesPerSecond: 48)
        let input = engine.inputNode
        try AudioInputDeviceManager.selectInputDevice(uid: inputDeviceUID, for: input)
        let format = input.inputFormat(forBus: 0)

        transcriptState.reset()
        let currentTranscriptState = transcriptState
        let recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result {
                let text = result.bestTranscription.formattedString
                if currentTranscriptState.updateIfChanged(text) {
                    onTranscript(text)
                }
            }

            if error != nil {
                recognitionRequest.endAudio()
            }
        }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 512, format: format) { [recognitionGain] buffer, _ in
            let recognitionBuffer = Self.amplifiedBuffer(from: buffer, gain: recognitionGain)
            recognitionRequest.append(recognitionBuffer)
            if levelThrottle.shouldEmit() {
                onLevel(Self.normalizedRMS(from: recognitionBuffer))
            }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            recognitionRequest.endAudio()
            recognitionTask.cancel()
            input.removeTap(onBus: 0)
            throw error
        }

        audioEngine = engine
        request = recognitionRequest
        task = recognitionTask
    }

    func stop() async -> String {
        let text = transcriptState.current
        request?.endAudio()
        task?.finish()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        task = nil
        request = nil
        audioEngine = nil
        return text
    }

    private static func amplifiedBuffer(from buffer: AVAudioPCMBuffer, gain: Float) -> AVAudioPCMBuffer {
        guard gain > 1, buffer.frameLength > 0 else { return buffer }
        guard
            let inputData = buffer.floatChannelData,
            let outputBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength),
            let outputData = outputBuffer.floatChannelData
        else { return buffer }

        outputBuffer.frameLength = buffer.frameLength
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        for channel in 0..<channelCount {
            let input = inputData[channel]
            let output = outputData[channel]
            for frame in 0..<frameLength {
                output[frame] = min(max(input[frame] * gain, -1), 1)
            }
        }

        return outputBuffer
    }

    private static func normalizedRMS(from buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard channelCount > 0, frameLength > 0 else { return 0 }

        var sum: Float = 0
        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameLength {
                let sample = samples[frame]
                sum += sample * sample
            }
        }

        let mean = sum / Float(channelCount * frameLength)
        let rms = sqrt(mean)
        let db = 20 * log10(max(rms, 0.000_001))
        let normalized = (Double(db) + 55) / 45
        return min(max(normalized, 0), 1)
    }

    enum TranscriptionError: Error {
        case speechNotAuthorized
        case recognizerUnavailable
    }
}

private final class TranscriptState: @unchecked Sendable {
    private let lock = NSLock()
    private var text = ""

    var current: String {
        lock.lock()
        defer { lock.unlock() }
        return text
    }

    func reset() {
        lock.lock()
        text = ""
        lock.unlock()
    }

    func updateIfChanged(_ newText: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard newText != text else {
            return false
        }
        text = newText
        return true
    }
}

private final class AudioLevelThrottle: @unchecked Sendable {
    private let minInterval: CFTimeInterval
    private let lock = NSLock()
    private var lastEmission: CFTimeInterval = 0

    init(maxFramesPerSecond: Double) {
        self.minInterval = 1 / maxFramesPerSecond
    }

    func shouldEmit() -> Bool {
        let now = CACurrentMediaTime()
        lock.lock()
        defer { lock.unlock() }

        guard now - lastEmission >= minInterval else {
            return false
        }
        lastEmission = now
        return true
    }
}
