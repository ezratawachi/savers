import AVFoundation

/// How a phrase is said. The ids are the web's, so the clips' names match.
enum SpeechTone: String {
    /// Imagine (and the breathing): calm, soft and slow.
    case calm = "visualizacion"
    /// Move: energetic, like a coach.
    case energetic = "ejercicio"
    /// Short notices: "Imagine is done."
    case notice = "aviso"

    var id: String { rawValue }

    /// What Gemini is asked for, with the accent of the app's language.
    var style: String {
        let accent = AppLanguage.isSpanish ? "Mexican Spanish accent." : "Natural American English accent."
        switch self {
        case .calm: return accent + " Calm, soft and slow, like a guided meditation, with gentle pauses."
        case .energetic: return accent + " Energetic, clear and encouraging, like a coach. Brisk pace."
        case .notice: return accent + " Neutral, warm and clear."
        }
    }
}

/// Spoken cues: Gemini's voice when its clip is on this iPhone, the iPhone's own voice in the app's language otherwise,
/// without a word about it.
final class Voice {
    static let shared = Voice()

    private let synth = AVSpeechSynthesizer()
    private lazy var voice: AVSpeechSynthesisVoice? = Self.bestVoice()
    /// Moves with every cue and every stop, so a delayed cue knows it's been overtaken.
    private(set) var seq = 0

    func say(_ text: String, _ tone: SpeechTone) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        stop()
        if let clip = GeminiVoice.shared.clip(text, tone) {
            ToneEngine.shared.clip(clip)
            return
        }
        ToneEngine.shared.applySession()
        let u = AVSpeechUtterance(string: text)
        u.voice = voice
        u.rate = AVSpeechUtteranceDefaultSpeechRate * (tone == .calm ? 0.86 : 0.94)
        u.preUtteranceDelay = 0.1
        synth.speak(u)
    }

    /// A long cue only speaks once its Gemini clip exists, so one routine never mixes voices; without a key, the iPhone says it.
    func say(full: String, short: String, _ tone: SpeechTone) {
        let g = GeminiVoice.shared
        say(!g.hasKey || g.clip(full, tone) != nil ? full : short, tone)
    }

    func stop() {
        seq += 1
        synth.stopSpeaking(at: .immediate)
        ToneEngine.shared.stop(.voice)
    }

    /// In the app's language: Premium or Enhanced first, then Mexican Spanish (or American English), then any.
    private static func bestVoice() -> AVSpeechSynthesisVoice? {
        let lang = AppLanguage.code
        let first = AppLanguage.isSpanish ? ["es-MX", "es-US"] : ["en-US", "en-GB"]
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(lang) }
        func rank(_ v: AVSpeechSynthesisVoice) -> Int {
            let q = v.quality == .premium ? 0 : v.quality == .enhanced ? 1 : 2
            return q * 10 + (first.firstIndex(of: v.language) ?? first.count)
        }
        return voices.min { rank($0) < rank($1) } ?? AVSpeechSynthesisVoice(language: first[0])
    }
}
