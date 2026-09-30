import AVFoundation

/// Plays the app's synthesized sounds, the exercise guide and Gemini's clips on one clock.
/// The engine only runs while something is sounding.
final class ToneEngine {
    static let shared = ToneEngine()

    private let engine = AVAudioEngine()
    private let bank: ToneBank
    private var stopTask: Task<Void, Never>?

    /// A guided timer is running: with "Mantener mi música" off, its sounds and voice pause your music and ignore the ring switch.
    var timerRunning = false {
        didSet { if timerRunning != oldValue { applySession() } }
    }

    private init() {
        let rate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        bank = ToneBank(sampleRate: rate > 0 ? rate : 48_000)
        let format = AVAudioFormat(standardFormatWithSampleRate: bank.sampleRate, channels: 1)
        let node = Self.sourceNode(bank)
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }

    private nonisolated static func sourceNode(_ bank: ToneBank) -> AVAudioSourceNode {
        AVAudioSourceNode { _, _, frameCount, buffers -> OSStatus in
            let list = UnsafeMutableAudioBufferListPointer(buffers)
            guard let data = list.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            bank.render(into: data, count: Int(frameCount))
            for extra in list.dropFirst() {
                extra.mData?.copyMemory(from: data, byteCount: Int(extra.mDataByteSize))
            }
            return noErr
        }
    }

    // MARK: Playing

    func tone(_ freq: Double, _ duration: Double, peak: Double, delay: Double = 0) {
        play(.sine(freq: freq, peak: peak), duration, delay, .ui)
    }

    /// A move of the exercise guide, from G4 up to D5 or back.
    func glide(up: Bool, duration: Double, level: Double, delay: Double) {
        let lo = 392.0, hi = 587.3
        play(.glide(from: up ? lo : hi, to: up ? hi : lo, level: level), max(0.3, duration - 0.06), delay, .guide)
    }

    func tick(delay: Double) { play(.tick, 0.07, delay, .guide) }

    /// The end of a drill: E5, then B5.
    func drillBell(delay: Double) {
        play(.bell(freq: 659.3, level: 0.2), 1.4, delay, .guide)
        play(.bell(freq: 987.8, level: 0.16), 1.4, delay + 0.22, .guide)
    }

    /// Speech: a cue (`.voice`) or a guide word (`.guide`, which cuts the cue it lands on).
    func clip(_ clip: VoiceClip, delay: Double = 0, group: ToneBank.Group = .voice) {
        guard start() else { return }
        bank.addClip(clip.samples, rate: clip.rate, delay: delay, group: group)
        stopWhenQuiet()
    }

    func stop(_ group: ToneBank.Group) { bank.stop(group) }

    private func play(_ kind: ToneBank.Kind, _ duration: Double, _ delay: Double, _ group: ToneBank.Group) {
        guard start() else { return }
        bank.add(kind, duration: duration, delay: delay, group: group)
        stopWhenQuiet()
    }

    // MARK: The session

    static var keepMusic: Bool {
        get { LocalPrefs.standard["keepMusic"] != "false" }
        set { LocalPrefs.standard["keepMusic"] = newValue ? "true" : "false"; shared.applySession() }
    }

    /// From launch: iOS's default would stop your music the first time anything sounds here, even a notice's bell.
    static func mixFromLaunch() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
    }

    /// Ambient mixes with your music and follows the ring switch; playback pauses other apps and always sounds.
    func applySession() {
        let s = AVAudioSession.sharedInstance()
        let category: AVAudioSession.Category = timerRunning && !Self.keepMusic ? .playback : .ambient
        if s.category != category { try? s.setCategory(category) }
        try? s.setActive(true)
    }

    private func start() -> Bool {
        if engine.isRunning { return true }
        applySession()
        do {
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    private func stopWhenQuiet() {
        stopTask?.cancel()
        stopTask = Task {
            while !Task.isCancelled {
                let left = bank.remaining
                try? await Task.sleep(for: .seconds(left + 0.5))
                guard !Task.isCancelled else { return }
                if bank.remaining == 0 {
                    engine.pause()
                    return
                }
            }
        }
    }
}
