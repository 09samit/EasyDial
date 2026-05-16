//
//  SpeechService.swift
//  EasyDial
//
//  AVSpeechSynthesizer wrapper with localization-aware voices for confirmations.
//

import AVFoundation
import Foundation

/// Own synthesizer on main queue only — keeps app launch graph simple while satisfying AVFoundation threading rules.
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var speakCompletion: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speakCalling(contactName: String, languageCode: String, voicePromptsEnabled: Bool) {
        guard voicePromptsEnabled else { return }
        let loc = Locale(identifier: languageCode)
        let format = L10n.string("speech.calling", locale: loc)
        let text = String(format: format, locale: loc, arguments: [contactName])
        speak(text: text, languageCode: languageCode)
    }

    func speakEmergencyActivated(languageCode: String, voicePromptsEnabled: Bool, completion: (() -> Void)? = nil) {
        guard voicePromptsEnabled else {
            completion?()
            return
        }
        let loc = Locale(identifier: languageCode)
        let text = L10n.string("speech.emergency_mode", locale: loc)
        speak(text: text, languageCode: languageCode, completion: completion)
    }

    func speak(text: String, languageCode: String, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            synthesizer.stopSpeaking(at: .immediate)
            speakCompletion = completion
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
                ?? AVSpeechSynthesisVoice(language: Locale.current.identifier)
                ?? AVSpeechSynthesisVoice.speechVoices().first
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        DispatchQueue.main.async { [weak self] in
            self?.speakCompletion = nil
            self?.synthesizer.stopSpeaking(at: .immediate)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let callback = speakCompletion
            speakCompletion = nil
            callback?()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let callback = speakCompletion
            speakCompletion = nil
            callback?()
        }
    }
}
