/// The drawing (and the move) of a step.
enum Fig: String, CaseIterable {
    case marcha, birddog, deadbug, puente, sentadilla, descanso

    /// The one line that says how to do it well, under the drawing and in the long cue.
    var tip: String {
        switch self {
        case .marcha: "Sube las rodillas, brazos sueltos"
        case .birddog: "La pierna no sube más que la cadera"
        case .deadbug: "Espalda baja pegada al piso"
        case .puente: "Aprieta glúteos, sin arquear la espalda"
        case .sentadilla: "Pecho arriba, toca la silla y sube"
        case .descanso: "Respira lento, suelta la espalda"
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

/// Ejercicio en casa: 8 minutes. Marcha, two rounds of four drills with a change between them, then breathing.
enum Exercise {
    static let circuit: [(String, Fig)] = [
        ("Bird dog", .birddog), ("Dead bug", .deadbug), ("Puente de glúteos", .puente), ("Sentadilla a silla", .sentadilla),
    ]

    static let steps: [ExStep] = {
        var s = [ExStep(name: "Marchar en el sitio", secs: 60, fig: .marcha)]
        for r in 1...2 {
            for (i, c) in circuit.enumerated() {
                s.append(ExStep(name: "\(c.0) (ronda \(r))", ex: c.0, round: r, secs: 40, fig: c.1))
                if !(r == 2 && i == circuit.count - 1) { s.append(ExStep(name: "Cambio", secs: 5, rest: true)) }
            }
        }
        s.append(ExStep(name: "Respiraciones con piernas en la silla", secs: 65, fig: .descanso))
        return s
    }()

    static let runSteps = steps.map { RunStep(secs: $0.secs, text: $0.name) }

    // MARK: Cues

    static let marchCue = "Marchar en el sitio, un minuto."

    static func cue(_ i: Int) -> String {
        guard steps.indices.contains(i) else { return "" }
        if i == 0 { return marchCue }
        let s = steps[i]
        if i == steps.count - 1 { return "Último: piernas en la silla, respira lento." }
        let name = (s.ex ?? "").lowercased()
        if s.round == 2 && s.ex == circuit[0].0 { return "Ronda dos: \(name)." }
        return "Sigue: \(name)."
    }

    /// The cue plus the step's tip ("Sigue: dead bug. Espalda baja pegada al piso."); the last step already says it.
    static func cueFull(_ i: Int) -> String {
        guard let fig = steps[safe: i]?.fig, fig != .descanso else { return cue(i) }
        return cue(i) + " " + fig.tip + "."
    }

    static let doneCue = "Listo. Ejercicio marcado."

    // MARK: The map

    /// Six parts in a row; the width of each is its name's bold width, so all fit on a 375-pt iPhone.
    static let map: [(fig: Fig, name: String, weight: Double)] = [
        (.marcha, "Marcha", 37), (.birddog, "Bird dog", 43), (.deadbug, "Dead bug", 48),
        (.puente, "Puente", 35), (.sentadilla, "Sentadilla", 52), (.descanso, "Respira", 39),
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
