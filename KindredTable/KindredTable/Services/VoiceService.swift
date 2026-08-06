import Foundation
import AVFoundation
import Speech
import Observation

enum VoiceCommand {
    case next, previous, repeatStep, stop

    /// Match the tail of a transcription to a command word.
    init?(matching text: String) {
        let t = text.lowercased()
        if t.contains("next") || t.contains("forward") { self = .next }
        else if t.contains("back") || t.contains("previous") || t.contains("go back") { self = .previous }
        else if t.contains("repeat") || t.contains("again") || t.contains("what") { self = .repeatStep }
        else if t.contains("stop") || t.contains("finish") || t.contains("done") { self = .stop }
        else { return nil }
    }
}

/// Text-to-speech for reading steps aloud, plus on-device speech recognition for
/// hands-free "next / back / repeat" commands while cooking.
@MainActor
@Observable
final class VoiceService {

    var isListening = false
    var lastHeard = ""
    var isSpeaking: Bool { synthesizer.isSpeaking }

    private let synthesizer = AVSpeechSynthesizer()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var onCommand: ((VoiceCommand) -> Void)?
    private var cooldownUntil: Date?

    // MARK: Speak

    func speak(_ text: String) {
        configurePlaybackSession()
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.96
        utterance.pitchMultiplier = 1.0
        utterance.voice = Self.preferredVoice ?? AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    /// The best-sounding English voice installed on this device: prefer Premium,
    /// then Enhanced, then a known-natural default. Users get a noticeably nicer
    /// voice if they've downloaded one in Settings ▸ Accessibility ▸ Spoken
    /// Content ▸ Voices; otherwise this still picks the best available.
    static let preferredVoice: AVSpeechSynthesisVoice? = {
        let english = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        let niceNames = ["Ava", "Zoe", "Joelle", "Nathan", "Evan", "Samantha", "Alex", "Serena", "Daniel"]
        func rank(_ v: AVSpeechSynthesisVoice) -> Int {
            var r = 0
            switch v.quality {
            case .premium: r += 6
            case .enhanced: r += 3
            default: break
            }
            if v.language == "en-US" { r += 2 }
            if niceNames.contains(where: { v.name.localizedCaseInsensitiveContains($0) }) { r += 1 }
            return r
        }
        return english.max { rank($0) < rank($1) }
    }()

    func stopSpeaking() { synthesizer.stopSpeaking(at: .immediate) }

    // MARK: Permissions

    func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
        let mic = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
        return speech && mic
    }

    // MARK: Listen

    func startListening(onCommand: @escaping (VoiceCommand) -> Void) {
        guard !isListening, let recognizer, recognizer.isAvailable else { return }
        self.onCommand = onCommand
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.request?.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            beginTask()
        } catch {
            isListening = false
        }
    }

    private func beginTask() {
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req
        task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    let text = result.bestTranscription.formattedString
                    self.lastHeard = text
                    if let now = self.cooldownUntil, now > Date() { return }
                    if let command = VoiceCommand(matching: text) {
                        self.cooldownUntil = Date().addingTimeInterval(1.5)
                        self.onCommand?(command)
                        self.resetTask()   // clear transcript so the next word is heard fresh
                    }
                }
                if error != nil { self.resetTask() }
            }
        }
    }

    /// Swap in a fresh recognition request without tearing down the mic tap.
    private func resetTask() {
        guard isListening else { return }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        beginTask()
    }

    func stopListening() {
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isListening = false
        onCommand = nil
    }

    // MARK: Helpers

    private func configurePlaybackSession() {
        // When only speaking (not listening), a plain playback category avoids
        // grabbing the mic.
        guard !isListening else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }
}
