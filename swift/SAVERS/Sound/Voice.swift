import AVFoundation

/// The iPhone's own Spanish voice for spoken cues. Gemini's voice replaces it in session 3 when its clip is ready.
/// Mixed with your music and quiet with the ring switch off, like the tones.
final class Voice {
    static let shared = Voice()

    enum Tone {
        /// Visualización: slow and calm.
        case calm
        /// Short notices: "Visualización lista."
        case notice
    }

    private let synth = AVSpeechSynthesizer()
    private lazy var voice: AVSpeechSynthesisVoice? = Self.bestSpanish()

    func say(_ text: String, _ tone: Tone) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        try? AVAudioSession.sharedInstance().setActive(true)
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = voice
        u.rate = AVSpeechUtteranceDefaultSpeechRate * (tone == .calm ? 0.86 : 0.94)
        u.preUtteranceDelay = 0.1
        synth.speak(u)
    }

    func stop() { synth.stopSpeaking(at: .immediate) }

    /// Premium or Enhanced first, then Mexican Spanish, then any Spanish.
    private static func bestSpanish() -> AVSpeechSynthesisVoice? {
        let spanish = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("es") }
        func rank(_ v: AVSpeechSynthesisVoice) -> Int {
            let q = v.quality == .premium ? 0 : v.quality == .enhanced ? 1 : 2
            return q * 10 + (v.language == "es-MX" ? 0 : v.language == "es-US" ? 1 : 2)
        }
        return spanish.min { rank($0) < rank($1) } ?? AVSpeechSynthesisVoice(language: "es-MX")
    }
}
