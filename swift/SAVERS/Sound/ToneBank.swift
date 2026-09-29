import Foundation
import Synchronization

/// The tones waiting to sound, shared between the app and the audio thread.
nonisolated final class ToneBank: Sendable {
    struct Tone {
        var start: Int64
        var frames: Int64
        var freq: Double
        var peak: Double
    }

    private struct State {
        var frame: Int64 = 0
        var tones: [Tone] = []
    }

    let sampleRate: Double
    private let state = Mutex(State())

    init(sampleRate: Double) { self.sampleRate = sampleRate }

    /// A sine with an 8 ms exponential attack and an exponential fall, `delay` seconds from now.
    func add(freq: Double, duration: Double, peak: Double, delay: Double) {
        state.withLock { s in
            let start = s.frame + Int64((delay + 0.01) * sampleRate)
            s.tones.append(Tone(start: start, frames: Int64(duration * sampleRate), freq: freq, peak: peak))
        }
    }

    /// Fills one buffer (mono float) and moves the clock on.
    func render(into out: UnsafeMutablePointer<Float>, count: Int) {
        state.withLock { s in
            let sr = sampleRate
            let attack = 0.008 * sr
            for i in 0..<count {
                let now = s.frame + Int64(i)
                var sum = 0.0
                for t in s.tones where now >= t.start && now < t.start + t.frames {
                    let x = Double(now - t.start)
                    let floor = 0.0001
                    let gain: Double
                    if x < attack {
                        gain = floor * pow(t.peak / floor, x / attack)
                    } else {
                        let rest = max(1, Double(t.frames) - attack)
                        gain = t.peak * pow(floor / t.peak, (x - attack) / rest)
                    }
                    sum += gain * sin(2 * .pi * t.freq * x / sr)
                }
                out[i] = Float(sum)
            }
            s.frame += Int64(count)
            s.tones.removeAll { $0.start + $0.frames < s.frame }
        }
    }

    var isIdle: Bool { state.withLock { $0.tones.isEmpty } }
}
