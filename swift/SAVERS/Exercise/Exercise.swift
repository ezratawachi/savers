import Foundation

/// The drawing (and the move) of a step.
enum Fig: String, CaseIterable {
    case marcha, birddog, deadbug, puente, sentadilla, descanso

    /// The one line that says how to do it well, under the drawing and in the long cue.
    var tip: String {
        switch self {
        case .marcha: String(localized: "Knees up, arms loose")
        case .birddog: String(localized: "Your leg goes no higher than your hip")
        case .deadbug: String(localized: "Lower back pressed to the floor")
        case .puente: String(localized: "Squeeze your glutes, without arching your back")
        case .sentadilla: String(localized: "Chest up, touch the chair and rise")
        case .descanso: String(localized: "Breathe slowly, let your back go")
        }
    }
}

/// One step of the home routine.
struct ExStep {
    var name: String
    /// The drill's name, for the cues ("Bird dog").
    var ex: String?
    var round = 0
    var secs: Double
    /// A 5-second change between drills.
    var rest = false
    var fig: Fig?
}

/// Move at home: 8 minutes. March, two rounds of four drills with a switch between them, then breathing.
enum Exercise {
    static let circuit: [(String, Fig)] = [
        (String(localized: "Bird dog"), .birddog), (String(localized: "Dead bug"), .deadbug),
        (String(localized: "Glute bridge"), .puente), (String(localized: "Chair squat"), .sentadilla),
    ]

    static let steps: [ExStep] = {
        var s = [ExStep(name: String(localized: "March in place"), secs: 60, fig: .marcha)]
        for r in 1...2 {
            for (i, c) in circuit.enumerated() {
                s.append(ExStep(name: String(localized: "\(c.0) (round \(r))"), ex: c.0, round: r, secs: 40, fig: c.1))
                if !(r == 2 && i == circuit.count - 1) { s.append(ExStep(name: String(localized: "Switch"), secs: 5, rest: true)) }
            }
        }
        s.append(ExStep(name: String(localized: "Breathing with your legs on the chair"), secs: 65, fig: .descanso))
        return s
    }()

    static let runSteps = steps.map { RunStep(secs: $0.secs, text: $0.name) }

    // MARK: Cues

    static let marchCue = String(localized: "March in place, one minute.")

    static func cue(_ i: Int) -> String {
        guard steps.indices.contains(i) else { return "" }
        if i == 0 { return marchCue }
        let s = steps[i]
        if i == steps.count - 1 { return String(localized: "Last one: legs on the chair, breathe slowly.") }
        let name = (s.ex ?? "").lowercased()
        if s.round == 2 && s.ex == circuit[0].0 { return String(localized: "Round two: \(name).") }
        return String(localized: "Next up: \(name).")
    }

    /// The cue plus the step's tip ("Next up: dead bug. Lower back pressed to the floor."); the last step already says it.
    static func cueFull(_ i: Int) -> String {
        guard let fig = steps[safe: i]?.fig, fig != .descanso else { return cue(i) }
        return cue(i) + " " + fig.tip + "."
    }

    static let doneCue = String(localized: "All done. Move is checked off.")

    // MARK: The map

    /// Six parts in a row; the width of each is its name's bold width, so all fit on a 375-pt iPhone.
    static let map: [(fig: Fig, name: String, weight: Double)] = [
        (.marcha, String(localized: "March"), 37), (.birddog, String(localized: "Bird dog"), 43), (.deadbug, String(localized: "Dead bug"), 48),
        (.puente, String(localized: "Bridge"), 35), (.sentadilla, String(localized: "Squat"), 52), (.descanso, Letter.silencio.name, 39),
    ]

    /// A change belongs to the part that comes next.
    static func part(of i: Int) -> Int {
        let fig = steps[safe: i]?.fig ?? steps[safe: i + 1]?.fig
        return map.firstIndex { $0.fig == fig } ?? -1
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
