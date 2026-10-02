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
        let own = days(of: kind).compactMap { w in ownTime(step, weekday: w).map { "\(Weekday.short[w]) \($0)" } }
        return ([all] + own).joined(separator: " · ")
    }

    /// "4 min · jue 10 min": the minutes for all days and the weekdays that have their own.
    func minutesSummary(_ kind: DayType, _ letter: Letter) -> String {
        let all = usualMinutes(kind, letter, weekday: nil)
        let own = days(of: kind).compactMap { w -> String? in
            let n = usualMinutes(kind, letter, weekday: w)
            return n == all ? nil : "\(Weekday.short[w]) " + String(localized: "\(n) min")
        }
        return ([String(localized: "\(all) min")] + own).joined(separator: " · ")
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
        /// Under "Dormido": "9:40 pm · 45 min antes", when "Prepararte para dormir" arrives.
        var windDown: String?
        var id: String { step.id ?? step.label }
    }

    /// Each group of a kind's hours, with its letters under the step that holds them (each letter once).
    func stepLines(_ kind: DayType) -> [(group: TypeSchedule.Group, lines: [StepLine])] {
        guard let t = settings.schedule?.type(kind) else { return [] }
        var seen: Set<Letter> = []
        let bedID = bedStep(kind)?.id
        return TypeSchedule.Group.allCases.compactMap { g in
            let list = t[g]
            guard !list.isEmpty else { return nil }
            let lines = list.indices.map { i -> StepLine in
                let st = list[i]
                let keys = st.letterKeys.filter { seen.insert($0).inserted }
                let next = i + 1 < list.count ? list[i + 1] : nil
                return StepLine(step: st, summary: stepSummary(st, kind), letters: letterLines(kind, st, keys), warnings: overlaps(kind, st, next: next, letters: keys),
                                windDown: g == .night && st.id == bedID ? windDownInfo(st) : nil)
            }
            return (g, lines)
        }
    }

    /// "9:40 pm · 45 min antes": the hour for all the days, before the "Dormido" it hangs from.
    private func windDownInfo(_ bed: Step) -> String {
        let mins = String(localized: "\(windDown) min before")
        guard let at = TimeText.minutes(bed.time) else { return mins }
        return TimeText.label((at - windDown + 24 * 60) % (24 * 60)) + " · " + mins
    }

    /// Each letter at the hour it starts: the block's hour plus the minutes of the letters before it.
    private func letterLines(_ kind: DayType, _ st: Step, _ keys: [Letter]) -> [LetterLine] {
        // A block that is just its step ("Más tarde · Lectura") already shows the hour above it.
        var at = keys.count == 1 && st.onlyStep != nil ? nil : TimeText.minutes(st.time)
        return keys.map { k in
            let min = letterMinutes(k, kind, weekday: nil)
            let mins = k.usualMinutes != nil ? minutesSummary(kind, k) : min > 0 ? String(localized: "\(min) min") : ""
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
            let msg = String(localized: "\(last.name) ends at \(TimeText.label(end)), past \(next.label) at \(TimeText.label(nextAt))")
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
}
