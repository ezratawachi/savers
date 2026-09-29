import AVFoundation

/// Plays the app's small synthesized sounds, mixed with your music and silent with the ring switch off.
/// The engine only runs while something is sounding.
final class ToneEngine {
    static let shared = ToneEngine()

    private let engine = AVAudioEngine()
    private let bank: ToneBank
    private var stopTask: Task<Void, Never>?

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

    func tone(_ freq: Double, _ duration: Double, peak: Double, delay: Double = 0) {
        guard start() else { return }
        bank.add(freq: freq, duration: duration, peak: peak, delay: delay)
        stopWhenQuiet(after: delay + duration + 0.5)
    }

    private func start() -> Bool {
        if engine.isRunning { return true }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    private func stopWhenQuiet(after seconds: Double) {
        stopTask?.cancel()
        stopTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, bank.isIdle else { return }
            engine.pause()
        }
    }
}
