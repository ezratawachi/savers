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

/// Move at home: the whole routine (8 minutes) or the short one (2), for a 10- or 20-minute sunrise.
/// March, the four drills (twice in the whole one) with a switch between them, then breathing.
struct Workout: Equatable {
    /// "full" or "short": two workouts are the same routine when this is.
    let id: String
    let steps: [ExStep]
    /// Each step as the timer runs it.
    let runSteps: [RunStep]
    /// Every sound of the guide, in routine seconds.
    let events: [GuideEvent]

    static let full = Workout(id: "full", march: 60, drill: 40, rounds: 2, breathe: 65)
    static let short = Workout(id: "short", march: 15, drill: 20, rounds: 1, breathe: 15)

    static func of(_ settings: AppSettings) -> Workout { settings.length?.shortMove == true ? .short : .full }

    static func == (a: Workout, b: Workout) -> Bool { a.id == b.id }

    private init(id: String, march: Double, drill: Double, rounds: Int, breathe: Double) {
        var s = [ExStep(name: String(localized: "March in place"), secs: march, fig: .marcha)]
        for r in 1...rounds {
            for (i, c) in Exercise.circuit.enumerated() {
                let name = rounds == 1 ? c.0 : String(localized: "\(c.0) (round \(r))")
                s.append(ExStep(name: name, ex: c.0, round: r, secs: drill, fig: c.1))
                if !(r == rounds && i == Exercise.circuit.count - 1) { s.append(ExStep(name: String(localized: "Switch"), secs: 5, rest: true)) }
            }
        }
        s.append(ExStep(name: String(localized: "Breathing with your legs on the chair"), secs: breathe, fig: .descanso))
        self.id = id
        steps = s
        runSteps = s.map { RunStep(secs: $0.secs, text: $0.name) }
        events = GuideEvent.all(s)
    }

    /// How long it lasts, as its card says it.
    var minutes: Int { max(1, Int((Runs.total(runSteps) / 60).rounded())) }

    var marchCue: String { steps[0].secs >= 60 ? Exercise.marchCue : String(localized: "March in place.") }

    // MARK: Cues

    func cue(_ i: Int) -> String {
        guard steps.indices.contains(i) else { return "" }
        if i == 0 { return marchCue }
        let s = steps[i]
        if i == steps.count - 1 { return String(localized: "Last one: legs on the chair, breathe slowly.") }
        let name = (s.ex ?? "").lowercased()
        if s.round == 2 && s.ex == Exercise.circuit[0].0 { return String(localized: "Round two: \(name).") }
        return String(localized: "Next up: \(name).")
    }

    /// The cue plus the step's tip ("Next up: dead bug. Lower back pressed to the floor."); the last step already says it.
    func cueFull(_ i: Int) -> String {
        guard let fig = steps[safe: i]?.fig, fig != .descanso else { return cue(i) }
        return cue(i) + " " + fig.tip + "."
    }

    /// A change belongs to the part that comes next.
    func part(of i: Int) -> Int {
        let fig = steps[safe: i]?.fig ?? steps[safe: i + 1]?.fig
        return Exercise.map.firstIndex { $0.fig == fig } ?? -1
    }

    /// Everything the voice can say in it, for Gemini to prepare.
    var phrases: [String] {
        [marchCue] + steps.indices.filter { $0 > 0 && !steps[$0].rest }.map(cue) + steps.indices.filter { !steps[$0].rest }.map(cueFull)
    }
}

/// What both routines share: the drills, the cues and the map of their six parts.
enum Exercise {
    static let circuit: [(String, Fig)] = [
        (String(localized: "Bird dog"), .birddog), (String(localized: "Dead bug"), .deadbug),
        (String(localized: "Glute bridge"), .puente), (String(localized: "Chair squat"), .sentadilla),
    ]

    static let marchCue = String(localized: "March in place, one minute.")

    static let doneCue = String(localized: "All done. Move is checked off.")

    /// Six parts in a row; the width of each is its name's bold width, so all fit on a 375-pt iPhone.
    static let map: [(fig: Fig, name: String, weight: Double)] = [
        (.marcha, String(localized: "March"), 37), (.birddog, String(localized: "Bird dog"), 43), (.deadbug, String(localized: "Dead bug"), 48),
        (.puente, String(localized: "Bridge"), 35), (.sentadilla, String(localized: "Squat"), 52), (.descanso, Letter.silencio.name, 39),
    ]
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
