import Foundation

/// Reading what an AI writes: names with or without accents, hours in any common way, days in Spanish or English.
enum AIText {
    /// "Visualización", " leer en" → "visualizacion", "leeren": how a name from the AI is compared with ours.
    static func key(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
            .lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// "5:45", "17:30", "8:50 pm", "8:50 p. m.", "9 pm", "5.45" → the app's "5:45" / "8:50 pm".
    static func time(_ v: JSONValue?) -> String? {
        guard let s = v?.text?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        let squeezed = s.replacingOccurrences(of: " ", with: "")
        let dotted = squeezed.replacing(/^(\d{1,2})\.(\d{2})/) { "\($0.1):\($0.2)" }
        if let m = TimeText.minutes(dotted) { return TimeText.label(m) }
        guard let p = dotted.wholeMatch(of: /(\d{1,2})([aApP])\.?[mM]?\.?/), let h = Int(p.1), (1...12).contains(h) else { return nil }
        return TimeText.minutes("\(h):00 \(p.2)m").map(TimeText.label)
    }

    /// "Breathe", "respira", "lee (L)", and the old "silencio", "lectura" → the step.
    static func letter(_ s: String) -> Letter? {
        let k = key(s)
        return Letter.allCases.first { l in l.knownNames.contains { k.hasPrefix(key($0)) } }
    }

    /// "normal", "Gym", "rest", "descanso", "sin savers", "off" → the kind a weekday or a date can be.
    static func dayType(_ v: JSONValue?) -> DayType? {
        guard let s = v?.text else { return nil }
        switch key(s) {
        case "normal": return .normal
        case "gym", "gimnasio", "diadegym", "gymday": return .gym
        case "sinsavers", "off", "libre", "descanso", "ninguno", "rest", "restday", "dayoff", "none": return .off
        default: return nil
        }
    }

    /// "jueves", "Jue", "miercoles", "Thursday", "thu" → 0 (Sunday) … 6 (Saturday).
    static func weekday(_ s: String) -> Int? {
        let p = Weekday.plain(s)
        return Weekday.keys.map(Weekday.plain).firstIndex(of: p) ?? englishDays.firstIndex(of: p)
    }

    private static let englishDays = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]

    /// A whole number, written as a number or as text ("15", "15 min").
    static func minutes(_ v: JSONValue?) -> Int? {
        if let n = v?.number, n.rounded() == n { return Int(n) }
        guard let s = v?.text, let m = s.firstMatch(of: /^\s*(\d+)/) else { return nil }
        return Int(m.1)
    }

    static func quoted(_ s: String) -> String { AppLanguage.isSpanish ? "«\(s)»" : "“\(s)”" }
}

extension Letter {
    /// "breathe", "respira": how the AI's configuration names it, in the app's language.
    var aiKey: String { AIText.key(name) }
}

extension Routine {
    /// A kind's blocks by the name the AI sees, in the day's order. Two blocks with the same title get "(2)".
    func aiBlocks(_ kind: DayType) -> [(name: String, step: Step)] {
        guard let t = settings.schedule?.type(kind) else { return [] }
        var out: [(name: String, step: Step)] = []
        var used: [String: Int] = [:]
        for g in TypeSchedule.Group.allCases {
            for st in t[g] where st.id != nil {
                let title = (st.title ?? "").trimmingCharacters(in: .whitespaces)
                var name = title.isEmpty ? st.label : title
                if name.isEmpty { name = String(localized: "Block \(out.count + 1)") }
                let n = used[AIText.key(name), default: 0] + 1
                used[AIText.key(name)] = n
                out.append((n == 1 ? name : "\(name) (\(n))", st))
            }
        }
        return out
    }

    func aiBlock(_ kind: DayType, named name: String) -> (name: String, step: Step)? {
        let k = AIText.key(name)
        return aiBlocks(kind).first { AIText.key($0.name) == k }
    }
}
