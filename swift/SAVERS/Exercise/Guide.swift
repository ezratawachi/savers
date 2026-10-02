import Foundation

/// What to do in each moment of a drill, by ear. Each move is a soft tone gliding for the whole move: up while
/// going up (reach, up, breathe in), down while going down; a hold ticks once a second, and a soft bell closes a drill.
/// Round 1 (and the breathing) also says the word on the first two reps, over a quieter glide, so the sound gets learned.
struct Guide {
    enum Move { case up, down, hold }

    struct Phase {
        var move: Move
        var secs: Double
        var word: String
    }

    var sides = false
    /// Quiet seconds before it starts: the breathing waits for its cue.
    var lead = 0.0
    var tone = SpeechTone.energetic
    var phases: [Phase]

    static func of(_ fig: Fig) -> Guide? {
        switch fig {
        case .marcha: nil
        case .birddog: Guide(sides: true, phases: [.init(move: .up, secs: 2, word: String(localized: "Reach")), .init(move: .hold, secs: 3, word: String(localized: "Hold")),
                                                   .init(move: .down, secs: 2, word: String(localized: "Back"))])
        case .deadbug: Guide(sides: true, phases: [.init(move: .down, secs: 3, word: String(localized: "Lower slowly")), .init(move: .up, secs: 2, word: String(localized: "Back"))])
        case .puente: Guide(phases: [.init(move: .up, secs: 2, word: String(localized: "Up")), .init(move: .hold, secs: 2, word: String(localized: "Hold")),
                                     .init(move: .down, secs: 2, word: String(localized: "Down"))])
        case .sentadilla: Guide(phases: [.init(move: .down, secs: 3, word: String(localized: "Down")), .init(move: .hold, secs: 0.5, word: String(localized: "Touch")),
                                         .init(move: .up, secs: 2, word: String(localized: "Up"))])
        case .descanso: Guide(lead: 5, tone: .calm, phases: [.init(move: .up, secs: 4, word: String(localized: "Breathe in")), .init(move: .down, secs: 6, word: String(localized: "Breathe out"))])
        }
    }

    static let wordReps = 2
    static let otherSide = String(localized: "Other side")
}

/// A drill's guide fitted to its step: reps stretched a little so the last one ends with the step.
struct GuidePlan {
    var fig: Fig
    var guide: Guide
    var n: Int
    /// Each phase's seconds, stretched.
    var d: [Double]
    var words: Bool

    var cycle: Double { d.reduce(0, +) }

    init?(step i: Int, of steps: [ExStep]) {
        guard let s = steps[safe: i], !s.rest, let fig = s.fig, let g = Guide.of(fig) else { return nil }
        let span = s.secs - g.lead
        let cycle = g.phases.reduce(0) { $0 + $1.secs }
        // Sides come in pairs, so both sides get the same number of reps.
        n = g.sides ? max(2, 2 * Int((span / (2 * cycle)).rounded())) : max(1, Int((span / cycle).rounded()))
        let k = span / (Double(n) * cycle)
        self.fig = fig
        guide = g
        d = g.phases.map { $0.secs * k }
        words = s.round != 2
    }

    /// The phase at `t` seconds into one rep.
    func phase(at t: Double) -> Int {
        var j = 0, acc = d[0]
        while j < d.count - 1 && t >= acc { j += 1; acc += d[j] }
        return j
    }
}

/// One sound of the routine, in routine seconds.
struct GuideEvent {
    enum Kind {
        case glide(Guide.Move, dur: Double, under: Bool)
        case tick
        case end
        case word(String, SpeechTone)
    }

    var at: Double
    var kind: Kind

    static func all(_ steps: [ExStep]) -> [GuideEvent] {
        var out: [GuideEvent] = []
        var start = 0.0
        for (i, s) in steps.enumerated() {
            defer { start += s.secs }
            guard let plan = GuidePlan(step: i, of: steps) else { continue }
            let g = plan.guide
            var t = start + g.lead
            for rep in 0..<plan.n {
                for (j, ph) in g.phases.enumerated() {
                    let d = plan.d[j], talk = plan.words && rep < Guide.wordReps
                    if talk {
                        let word = j == 0 && g.sides && rep % 2 == 1 ? Guide.otherSide : ph.word
                        out.append(GuideEvent(at: t, kind: .word(word, g.tone)))
                    }
                    if ph.move == .hold {
                        let ticks = max(1, Int(ph.secs.rounded()))
                        for q in 0..<ticks { out.append(GuideEvent(at: t + d * Double(q) / Double(ticks), kind: .tick)) }
                    } else {
                        out.append(GuideEvent(at: t, kind: .glide(ph.move, dur: d, under: talk)))
                    }
                    t += d
                }
            }
            // The last step ends with the routine's own sound.
            if i < steps.count - 1 { out.append(GuideEvent(at: start + s.secs, kind: .end)) }
        }
        return out.sorted { $0.at < $1.at }
    }

    /// Every guide word with its tone, once (both routines say the same ones).
    static let words: [(String, SpeechTone)] = {
        var seen = Set<String>(), out: [(String, SpeechTone)] = []
        for e in Workout.full.events {
            if case let .word(w, tone) = e.kind, seen.insert(tone.id + w).inserted { out.append((w, tone)) }
        }
        return out
    }()
}
