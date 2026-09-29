import Foundation
import Synchronization

/// The sounds waiting to play, shared between the app and the audio thread. Everything is scheduled in frames
/// on one clock, so the exercise guide keeps its rhythm no matter when the app's timer fires.
nonisolated final class ToneBank: Sendable {
    enum Kind {
        /// An interface tone: a sine with an 8 ms exponential attack and an exponential fall.
        case sine(freq: Double, peak: Double)
        /// The guide's move: a sine and a soft octave gliding a fifth over the whole move.
        case glide(from: Double, to: Double, level: Double)
        /// A soft wooden tick for each second of a hold.
        case tick
        /// A soft FM bell.
        case bell(freq: Double, level: Double)
        /// Recorded speech (mono float at its own rate).
        case clip(samples: [Float], rate: Double)
    }

    /// Which sounds can be stopped together.
    enum Group { case ui, guide, voice }

    struct Sound {
        var start: Int64
        var frames: Int64
        var kind: Kind
        var group: Group
        var phase = 0.0
        var modPhase = 0.0
    }

    private struct State {
        var frame: Int64 = 0
        var sounds: [Sound] = []
    }

    let sampleRate: Double
    private let state = Mutex(State())

    init(sampleRate: Double) { self.sampleRate = sampleRate }

    /// Plays `kind` for `duration` seconds, `delay` seconds from now.
    func add(_ kind: Kind, duration: Double, delay: Double, group: Group) {
        state.withLock { s in
            let start = s.frame + Int64((max(0, delay) + 0.01) * sampleRate)
            s.sounds.append(Sound(start: start, frames: Int64(duration * sampleRate), kind: kind, group: group))
        }
    }

    /// A clip that starts cuts the voice that was talking at that moment.
    func addClip(_ samples: [Float], rate: Double, delay: Double, group: Group) {
        state.withLock { s in
            let start = s.frame + Int64((max(0, delay) + 0.01) * sampleRate)
            for i in s.sounds.indices where s.sounds[i].group == .voice && s.sounds[i].start + s.sounds[i].frames > start {
                s.sounds[i].frames = max(0, start - s.sounds[i].start)
            }
            let frames = Int64(Double(samples.count) / rate * sampleRate)
            s.sounds.append(Sound(start: start, frames: frames, kind: .clip(samples: samples, rate: rate), group: group))
        }
    }

    func stop(_ group: Group) {
        state.withLock { s in s.sounds.removeAll { $0.group == group } }
    }

    /// Seconds left of the longest sound still playing.
    var remaining: Double {
        state.withLock { s in
            let end = s.sounds.map { $0.start + $0.frames }.max() ?? s.frame
            return Double(max(0, end - s.frame)) / sampleRate
        }
    }

    /// Fills one buffer (mono float) and moves the clock on.
    func render(into out: UnsafeMutablePointer<Float>, count: Int) {
        state.withLock { s in
            let sr = sampleRate
            for i in 0..<count { out[i] = 0 }
            var guideBus = [Float](repeating: 0, count: count)
            for n in s.sounds.indices {
                var snd = s.sounds[n]
                let from = max(0, Int(snd.start - s.frame))
                let to = min(count, Int(snd.start + snd.frames - s.frame))
                guard from < to else { continue }
                // Speech never goes through the limiter.
                var limited = snd.group == .guide
                if case .clip = snd.kind { limited = false }
                for i in from..<to {
                    let x = Double(s.frame + Int64(i) - snd.start)
                    let v = Float(Self.sample(&snd, x: x, sr: sr))
                    if limited { guideBus[i] += v } else { out[i] += v }
                }
                s.sounds[n] = snd
            }
            // A safety net against clipping when the guide's sounds overlap: past −6 dB it squeezes 12 to 1.
            for i in 0..<count {
                let g = guideBus[i], a = abs(g)
                out[i] += a <= 0.5 ? g : (g < 0 ? -1 : 1) * (0.5 + (a - 0.5) / 12)
            }
            s.frame += Int64(count)
            s.sounds.removeAll { $0.start + $0.frames < s.frame }
        }
    }

    private static let floor = 0.0001

    /// Exponential ramp from a to b over k in 0…1.
    private static func ramp(_ a: Double, _ b: Double, _ k: Double) -> Double { a * pow(b / a, min(1, max(0, k))) }

    private static func sample(_ snd: inout Sound, x: Double, sr: Double) -> Double {
        let t = x / sr
        switch snd.kind {
        case let .sine(freq, peak):
            let attack = 0.008 * sr
            let gain = x < attack ? ramp(floor, peak, x / attack) : ramp(peak, floor, (x - attack) / max(1, Double(snd.frames) - attack))
            return gain * sin(2 * .pi * freq * t)

        case let .glide(f0, f1, level):
            let end = Double(snd.frames) / sr
            let gain: Double
            if t < 0.12 { gain = ramp(floor, level, t / 0.12) }
            else if t < end - 0.25 { gain = level }
            else { gain = ramp(level, floor, (t - (end - 0.25)) / 0.25) }
            let f = ramp(f0, f1, t / end)
            snd.phase += 2 * .pi * f / sr
            return gain * (sin(snd.phase) + 0.18 * sin(2 * snd.phase))

        case .tick:
            let f = t < 0.05 ? ramp(1050, 800, t / 0.05) : 800
            let gain = t < 0.004 ? ramp(floor, 0.22, t / 0.004) : ramp(0.22, floor, (t - 0.004) / 0.066)
            snd.phase += f / sr
            let p = snd.phase - snd.phase.rounded(.down)
            return gain * (p < 0.5 ? 4 * p - 1 : 3 - 4 * p)

        case let .bell(f, level):
            let depth = ramp(f * 0.8, f * 0.05, t / 1.2)
            snd.modPhase += 2 * .pi * 2 * f / sr
            snd.phase += 2 * .pi * (f + depth * sin(snd.modPhase)) / sr
            let gain = t < 0.01 ? ramp(floor, level, t / 0.01) : ramp(level, floor, (t - 0.01) / 1.39)
            return gain * sin(snd.phase)

        case let .clip(samples, rate):
            let pos = t * rate, i = Int(pos)
            guard i + 1 < samples.count else { return i < samples.count ? Double(samples[i]) : 0 }
            let k = pos - Double(i)
            return Double(samples[i]) * (1 - k) + Double(samples[i + 1]) * k
        }
    }
}
