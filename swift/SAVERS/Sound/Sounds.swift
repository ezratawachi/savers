/// The interface's sounds, the same notes as the web.
enum Sounds {
    /// "Check doble": two quick notes up.
    static func check() {
        let e = ToneEngine.shared
        e.tone(988, 0.10, peak: 0.12)
        e.tone(1319, 0.14, peak: 0.12, delay: 0.07)
    }

    /// "Arpegio en mi": the same notes as the check, landing higher. For reaching a finish.
    static func complete() {
        let e = ToneEngine.shared
        for (i, f) in [659.0, 831, 988, 1319].enumerated() { e.tone(f, 0.14, peak: 0.12, delay: Double(i) * 0.085) }
        e.tone(1661, 0.2, peak: 0.1, delay: 0.34)
        e.tone(1976, 0.75, peak: 0.12, delay: 0.42)
        e.tone(3952, 0.25, peak: 0.014, delay: 0.42)
    }

    /// A short beep: a timer starting (880 Hz) or its last seconds.
    static func beep(_ freq: Double, _ duration: Double) {
        ToneEngine.shared.tone(freq, duration, peak: 0.16)
    }

    /// A soft bell: a new question, a timer that ends.
    static func bell() {
        let e = ToneEngine.shared
        e.tone(1175, 1.1, peak: 0.1)
        e.tone(3243, 0.3, peak: 0.03)
    }

    /// "Ten seconds left", barely there.
    static func softTone() {
        ToneEngine.shared.tone(660, 0.35, peak: 0.05)
    }
}
