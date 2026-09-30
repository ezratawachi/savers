import Foundation

/// The rules of the routine, read from the settings and the days. A plain value: the store hands out a
/// fresh one after every change, and views ask it what to show.
struct Routine {
    var settings: AppSettings
    var days: [String: Day]
    var today: String

    func day(_ ds: String) -> Day { days[ds] ?? Day(date: ds) }

    // MARK: Kind of day

    func weekType(_ w: Int) -> DayType {
        if w == 6 { return .shabbat }
        if let t = settings.schedule?.week[String(w)].flatMap(DayType.init(rawValue:)), DayType.choosable.contains(t) { return t }
        return DayType.defaultWeek[w] ?? .off
    }

    func weekDayType(_ ds: String) -> DayType { weekType(DayKey.weekday(ds)) }

    /// A date can be something else for that day only (the gym got cancelled, a holiday).
    func dayType(_ ds: String) -> DayType {
        let t = weekDayType(ds)
        if t != .shabbat, let own = days[ds]?.type.flatMap(DayType.init(rawValue:)), DayType.choosable.contains(own) { return own }
        return t
    }

    func isScheduled(_ ds: String) -> Bool { dayType(ds).hasSavers }

    /// Whose hours a date uses: gym on a gym day, normal otherwise (an off day with SAVERS uses normal).
    func scheduleKind(_ ds: String) -> DayType { dayType(ds) == .gym ? .gym : .normal }

    // MARK: Hours and minutes

    /// Most specific first: this date, this weekday, every day.
    func time(of step: Step, on ds: String?) -> String {
        if let ds {
            if let id = step.id, let t = days[ds]?.times?[id], !t.isEmpty { return t }
            if let times = step.times, let k = Weekday.key(in: times, for: DayKey.weekday(ds)), let t = times[k] { return t }
        }
        return step.time ?? ""
    }

    /// When a letter that's "Más tarde" happens on this day.
    func laterTime(_ kind: DayType, _ letter: Letter, on ds: String) -> String {
        guard let step = settings.schedule?.type(kind)?[.later].first(where: { $0.letterKeys.contains(letter) }) else { return "" }
        return time(of: step, on: ds)
    }

    static func valid(_ v: JSONValue?) -> Int? {
        guard let n = v?.number, n >= 1, n <= 240, n.rounded() == n else { return nil }
        return Int(n)
    }

    /// Silencio's and Lectura's minutes: this weekday of the schedule, or all its days, or the usual.
    func usualMinutes(_ kind: DayType, _ letter: Letter, weekday w: Int?) -> Int {
        let t = settings.schedule?.type(kind)
        if let w, let own = t?.minutesDays?[letter.rawValue], let k = Weekday.key(in: own, for: w), let n = Self.valid(own[k]) { return n }
        return Self.valid(t?.minutes?[letter.rawValue]) ?? letter.usualMinutes ?? 0
    }

    func minutesOn(_ kind: DayType, _ letter: Letter, on ds: String) -> Int {
        Self.valid(days[ds]?.mins?[letter.rawValue]) ?? usualMinutes(kind, letter, weekday: DayKey.weekday(ds))
    }

    /// How long a letter takes on a date; 0 when it isn't known.
    func letterMinutes(_ letter: Letter, _ kind: DayType, on ds: String) -> Int {
        letter.usualMinutes != nil ? minutesOn(kind, letter, on: ds) : fixedMinutes(letter, kind)
    }

    /// How long a letter usually takes on a weekday (nil: on all the days of its kind).
    func letterMinutes(_ letter: Letter, _ kind: DayType, weekday w: Int?) -> Int {
        letter.usualMinutes != nil ? usualMinutes(kind, letter, weekday: w) : fixedMinutes(letter, kind)
    }

    /// The letters whose minutes come from what's in them, not from a setting.
    private func fixedMinutes(_ letter: Letter, _ kind: DayType) -> Int {
        switch letter {
        case .silencio, .lectura: letter.usualMinutes ?? 0
        case .afirmaciones: max(1, Int((Double(settings.affirmations.filled.count * 25) / 60).rounded(.up)))
        case .visualizacion: max(1, settings.visualization.items.filled.count)
        case .ejercicio: kind == .gym ? TimeText.span(settings.schedule?.gymTime) ?? 0 : 8
        case .escritura: 2
        }
    }

    // MARK: The day's guide

    /// The schedule's blocks that hold letters, in order, "Más tarde" last. Letters no block places go in a
    /// block with no heading before "Más tarde" (all six when there's no schedule).
    func blocks(_ ds: String) -> [Block] {
        let kind = scheduleKind(ds)
        let t = settings.schedule?.type(kind)
        var seen: Set<Letter> = []
        var morning: [Block] = []
        var later: [Block] = []
        func add(_ id: String, _ head: [String]?, _ letters: [Letter], isLater: Bool) {
            let keys = letters.filter { seen.insert($0).inserted }
            guard !keys.isEmpty else { return }
            let b = Block(id: id, head: head, letters: keys, isLater: isLater)
            if isLater { later.append(b) } else { morning.append(b) }
        }
        for (i, st) in (t?[.steps] ?? []).enumerated() {
            add(st.id ?? "s\(i)", [time(of: st, on: ds), st.label], st.letterKeys, isLater: false)
        }
        for (i, st) in (t?[.later] ?? []).enumerated() {
            add(st.id ?? "l\(i)", ["Más tarde", time(of: st, on: ds)], st.letterKeys, isLater: true)
        }
        add("rest", nil, Letter.allCases, isLater: false)
        return morning + later
    }

    /// The first unmarked letter in the day's order: progress decides, never the clock.
    func nextLetter(_ blocks: [Block], _ d: Day) -> Letter? {
        blocks.lazy.flatMap(\.letters).first { !d.isDone($0) }
    }

    /// "day" with all six; "morning" (today only) when the morning is done and "Más tarde" is still to go.
    func finish(_ ds: String) -> Finish {
        let d = day(ds)
        if d.doneCount == 6 { return .day }
        guard ds == today else { return .none }
        let bs = blocks(ds)
        let morningDone = bs.allSatisfy { $0.isLater || $0.letters.allSatisfy(d.isDone) }
        return bs.contains(where: \.isLater) && morningDone ? .morning : .none
    }

    /// Days in a row with SAVERS complete; days without SAVERS don't break it. If today's isn't done yet, from yesterday.
    func streak() -> Int {
        var ds = today
        if isScheduled(ds) && day(ds).doneCount < 6 { ds = DayKey.adding(-1, to: ds) }
        var n = 0
        for _ in 0..<800 {
            if isScheduled(ds) {
                if day(ds).doneCount == 6 { n += 1 } else { break }
            }
            ds = DayKey.adding(-1, to: ds)
        }
        return n
    }

    // MARK: The sun

    /// When a letter of today's morning should start and how long it lasts, in minutes of the day.
    func sunPlan(_ letter: Letter) -> (start: Int, length: Int)? {
        let ds = today
        guard isScheduled(ds) else { return nil }
        let kind = scheduleKind(ds)
        for b in blocks(ds) where !b.isLater && b.head != nil && b.letters.contains(letter) {
            guard var at = TimeText.minutes(b.head?.first) else { return nil }
            for k in b.letters {
                let m = letterMinutes(k, kind, on: ds)
                if k == letter { return m > 0 ? (at, m) : nil }
                at += m
            }
        }
        return nil
    }

    /// What comes after this letter: the next letter still to do, or the next thing in the schedule ("Baño").
    func sunNext(after letter: Letter) -> String {
        let ds = today, d = day(ds)
        let keys = blocks(ds).filter { !$0.isLater }.flatMap(\.letters)
        if let i = keys.firstIndex(of: letter), let next = keys[(i + 1)...].first(where: { !d.isDone($0) }) { return next.name }
        let steps = settings.schedule?.type(scheduleKind(ds))?[.steps] ?? []
        guard let at = steps.firstIndex(where: { $0.letterKeys.contains(letter) }) else { return "" }
        for st in steps[(at + 1)...] {
            let open = st.letterKeys.contains { !d.isDone($0) }
            if (st.letters ?? []).isEmpty || open { return st.label }
        }
        return ""
    }

    // MARK: Other

    func affirmationReviewDue(reviewed: String?) -> Bool { reviewed != DayKey.month(today) }
}
