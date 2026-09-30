import Foundation

/// What Ajustes › Horario and the day sheet show: the usual hours, their summaries, and what runs late.
extension Routine {
    /// The weekdays (0…5) that are this kind.
    func days(of kind: DayType) -> [Int] { (0...5).filter { weekType($0) == kind } }

    /// A step's own hour on one weekday, if it has one.
    func ownTime(_ step: Step, weekday w: Int) -> String? {
        guard let times = step.times, let k = Weekday.key(in: times, for: w), let t = times[k], !t.isEmpty else { return nil }
        return t
    }

    /// A step's hour on a weekday, or for all its days (nil).
    func usualTime(_ step: Step, weekday w: Int?) -> String {
        w.flatMap { ownTime(step, weekday: $0) } ?? step.time ?? ""
    }

    func step(_ kind: DayType, id: String) -> Step? {
        guard let t = settings.schedule?.type(kind) else { return nil }
        return TypeSchedule.Group.allCases.lazy.flatMap { t[$0] }.first { $0.id == id }
    }

    /// "5:20 · jue 5:10": the hour for all days and the weekdays that have their own.
    func stepSummary(_ step: Step, _ kind: DayType) -> String {
        let all = (step.time ?? "").isEmpty ? "—" : step.time ?? ""
        let own = days(of: kind).compactMap { w in ownTime(step, weekday: w).map { "\(Weekday.keys[w]) \($0)" } }
        return ([all] + own).joined(separator: " · ")
    }

    /// "4 min · jue 10 min": the minutes for all days and the weekdays that have their own.
    func minutesSummary(_ kind: DayType, _ letter: Letter) -> String {
        let all = usualMinutes(kind, letter, weekday: nil)
        let own = days(of: kind).compactMap { w -> String? in
            let n = usualMinutes(kind, letter, weekday: w)
            return n == all ? nil : "\(Weekday.keys[w]) \(n) min"
        }
        return (["\(all) min"] + own).joined(separator: " · ")
    }

    /// A weekday's own minutes, if it has them.
    func ownMinutes(_ kind: DayType, _ letter: Letter, weekday w: Int) -> Int? {
        guard let own = settings.schedule?.type(kind)?.minutesDays?[letter.rawValue], let k = Weekday.key(in: own, for: w) else { return nil }
        return Self.valid(own[k])
    }

    // MARK: Ajustes › Horario

    struct LetterLine: Identifiable {
        let letter: Letter
        /// "5:32 · 10 min"
        let info: String
        var id: Letter { letter }
    }

    struct StepLine: Identifiable {
        let step: Step
        let summary: String
        let letters: [LetterLine]
        /// "Lectura termina 6:12, pasa las 6:10 de Baño"
        let warnings: [String]
        var id: String { step.id ?? step.label }
    }

    /// Each group of a kind's hours, with its letters under the step that holds them (each letter once).
    func stepLines(_ kind: DayType) -> [(group: TypeSchedule.Group, lines: [StepLine])] {
        guard let t = settings.schedule?.type(kind) else { return [] }
        var seen: Set<Letter> = []
        return TypeSchedule.Group.allCases.compactMap { g in
            let list = t[g]
            guard !list.isEmpty else { return nil }
            let lines = list.indices.map { i -> StepLine in
                let st = list[i]
                let keys = st.letterKeys.filter { seen.insert($0).inserted }
                let next = i + 1 < list.count ? list[i + 1] : nil
                return StepLine(step: st, summary: stepSummary(st, kind), letters: letterLines(kind, st, keys), warnings: overlaps(kind, st, next: next, letters: keys))
            }
            return (g, lines)
        }
    }

    /// Each letter at the hour it starts: the block's hour plus the minutes of the letters before it.
    private func letterLines(_ kind: DayType, _ st: Step, _ keys: [Letter]) -> [LetterLine] {
        // A block that is just its letter ("Más tarde · Lectura") already shows the hour above it.
        var at = keys.count == 1 && keys[0].name == st.title ? nil : TimeText.minutes(st.time)
        return keys.map { k in
            let min = letterMinutes(k, kind, weekday: nil)
            let mins = k.usualMinutes != nil ? minutesSummary(kind, k) : min > 0 ? "\(min) min" : ""
            let info = [at.map(TimeText.label) ?? "", mins].filter { !$0.isEmpty }.joined(separator: " · ")
            if let a = at { at = a + min }
            return LetterLine(letter: k, info: info)
        }
    }

    /// When a block's letters run past the next hour it says so, with the weekdays it happens on.
    private func overlaps(_ kind: DayType, _ st: Step, next: Step?, letters: [Letter]) -> [String] {
        guard let next, let last = letters.last else { return [] }
        let ds = days(of: kind)
        var found: [String: [Int?]] = [:]
        var order: [String] = []
        for w in ds.isEmpty ? [nil] : ds.map(Optional.some) {
            guard let start = TimeText.minutes(usualTime(st, weekday: w)),
                  let nextAt = TimeText.minutes(usualTime(next, weekday: w)), nextAt > start else { continue }
            let end = start + letters.reduce(0) { $0 + letterMinutes($1, kind, weekday: w) }
            guard end > nextAt else { continue }
            let msg = "\(last.name) termina \(TimeText.label(end)), pasa las \(TimeText.label(nextAt)) de \(next.label)"
            if found[msg] == nil { order.append(msg) }
            found[msg, default: []].append(w)
        }
        return order.map { msg in
            let ws = found[msg] ?? []
            guard !ds.isEmpty, ws.count != ds.count else { return msg }
            return Weekday.plurals(ws.compactMap { $0 }).capitalizedFirst + ": " + msg
        }
    }

    // MARK: One date

    /// This date has an hour or minutes of its own.
    func dateEdited(_ ds: String) -> Bool {
        guard let d = days[ds] else { return false }
        if [Letter.silencio, .lectura].contains(where: { Self.valid(d.mins?[$0.rawValue]) != nil }) { return true }
        guard let times = d.times, let t = settings.schedule?.type(dayType(ds)) else { return false }
        return TypeSchedule.Group.allCases.contains { g in t[g].contains { $0.id.flatMap { times[$0] }?.isEmpty == false } }
    }

    // MARK: The copy's summary

    /// The routine weekday by weekday, for whoever reads the copy (an AI helping to adjust it).
    func weekSummary() -> [String: JSONValue] {
        var out: [String: JSONValue] = [:]
        for w in 0...6 {
            let type = weekType(w)
            guard type.hasSavers else {
                out[Weekday.names[w]] = .object(["tipo": .string(type == .off ? type.name : "Shabbat")])
                continue
            }
            var seen: Set<Letter> = []
            var letras: [JSONValue] = []
            let t = settings.schedule?.type(type)
            for g in TypeSchedule.Group.allCases {
                for st in t?[g] ?? [] {
                    var at = TimeText.minutes(usualTime(st, weekday: w))
                    for k in st.letterKeys where seen.insert(k).inserted {
                        let min = letterMinutes(k, type, weekday: w)
                        letras.append(.object([
                            "letra": .string(k.name), "bloque": .string(st.title ?? ""),
                            "hora": .string(at.map(TimeText.label) ?? ""), "minutos": .number(Double(min)),
                        ]))
                        if let a = at { at = a + min }
                    }
                }
            }
            out[Weekday.names[w]] = .object(["tipo": .string(type.name), "letras": .array(letras)])
        }
        return out
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
