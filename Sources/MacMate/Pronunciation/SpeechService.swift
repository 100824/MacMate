import AVFoundation
import Foundation
import NaturalLanguage

@MainActor
final class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()

    var availableVoices: [(identifier: String, name: String)] {
        AVSpeechSynthesisVoice.speechVoices()
            .map { ($0.identifier, "\($0.name)（\($0.language)）") }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }

    func speak(_ text: String, voiceIdentifier: String, rate: Double) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        if !voiceIdentifier.isEmpty {
            utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        } else {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(text)
            switch recognizer.dominantLanguage {
            case .simplifiedChinese: utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
            case .traditionalChinese: utterance.voice = AVSpeechSynthesisVoice(language: "zh-TW")
            case .english: utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            default: break
            }
        }
        utterance.rate = min(AVSpeechUtteranceMaximumSpeechRate, max(AVSpeechUtteranceMinimumSpeechRate, Float(rate / 400)))
        synthesizer.speak(utterance)
        FileLogger.shared.info(.app, "speech_started chars=\(text.count) voice_configured=\(!voiceIdentifier.isEmpty)")
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
