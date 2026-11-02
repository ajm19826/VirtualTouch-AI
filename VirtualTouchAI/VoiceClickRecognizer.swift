import Foundation
import AVFoundation
import Speech

final class VoiceClickRecognizer {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    var onClick: (() -> Void)?
    var onStop: (() -> Void)?
    private var lastTriggeredPhrase = ""
    private var lastTriggerTime = Date(timeIntervalSince1970: 0)

    func start(onAllowed: @escaping (Bool, String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] speechStatus in
            guard speechStatus == .authorized else {
                onAllowed(false, "Speech recognition permission is required")
                return
            }
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                DispatchQueue.main.async {
                    self?.beginRecognition()
                    onAllowed(true, "Listening for Click, Left, or Stop")
                }
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { micAllowed in
                    DispatchQueue.main.async {
                        if micAllowed {
                            self?.beginRecognition()
                            onAllowed(true, "Listening for Click, Left, or Stop")
                        } else {
                            onAllowed(false, "Microphone permission is required")
                        }
                    }
                }
            default:
                DispatchQueue.main.async {
                    onAllowed(false, "Microphone permission is required")
                }
            }
        }
    }

    func stop() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
    }

    private func beginRecognition() {
        stop()
        guard let recognizer, recognizer.isAvailable else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let result else { return }
            let phrase = result.bestTranscription.formattedString.lowercased()
            let recentWords = phrase.split(separator: " ").suffix(3).joined(separator: " ")
            let trigger = recentWords.contains("stop") ? "stop" : recentWords.contains("left") ? "left" : recentWords.contains("click") ? "click" : ""
            guard !trigger.isEmpty else { return }
            guard Date().timeIntervalSince1970 - (self?.lastTriggerTime.timeIntervalSince1970 ?? 0) > 0.8 else { return }
            self?.lastTriggeredPhrase = trigger
            self?.lastTriggerTime = Date()
            DispatchQueue.main.async {
                if trigger == "stop" { self?.onStop?() } else { self?.onClick?() }
            }
        }

        engine.prepare()
        try? engine.start()
    }
}
