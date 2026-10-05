import Foundation

/// The rules of the routine, read from the settings and the days. A plain value: the store hands out a
/// fresh one after every change, and views ask it what to show.
struct Routine {
    var settings: AppSettings
    var days: [String: Day]
    var today: String

    func day(_ ds: String) -> Day { days[ds] ?? Day(date: ds) }

    // MARK: Kind of day

    /// A kind by its id, a deleted one too: the past still says it.
    func kind(_ id: String?) -> DayType? {
        guard let id, let t = settings.schedule?.types?[id] else { return nil }
        return DayType(id: id, t)
    }

    /// The kinds you have, oldest first; always one with the sunrise.
    var types: [DayType] {
        let all = (settings.schedule?.types ?? [:]).map { DayType(id: $0.key, $0.value) }
            .filter { !$0.deleted }
            .sorted { ($0.order, $0.id) < ($1.order, $1.id) }
        return all.contains(where: \.hasSunrise) ? all : [Self.plainNormal] + all
    }

    /// Before there's a schedule: a Normal with no hours.
    private static let plainNormal = DayType(id: DayType.normal, TypeSchedule())

    /// What a day uses when it needs some kind (one it doesn't know, a day of rest done anyway): the oldest
    /// with the sunrise.
    var firstSunrise: DayType { types.first(where: \.hasSunrise) ?? Self.plainNormal }

    /// What a weekday is now.
    func weekType(_ w: Int) -> DayType {
        kind(settings.schedule?.week[String(w)]).flatMap { $0.deleted ? nil : $0 } ?? firstSunrise
    }

    /// What a date's weekday was: before today, the week it had then, so the past never changes.
    func weekDayType(_ ds: String) -> DayType {
        let week = settings.schedule?.week(on: ds, today: today) ?? [:]
        if let k = kind(week[String(DayKey.weekday(ds))]), !k.deleted || ds < today { return k }
        return firstSunrise
    }

    /// A date can be another kind for that day only (the gym got cancelled, a holiday).
    func dayType(_ ds: String) -> DayType {
        if let own = kind(days[ds]?.type), !own.deleted || ds < today { return own }
        return weekDayType(ds)
    }

    func isScheduled(_ ds: String) -> Bool { dayType(ds).hasSunrise }

    /// Whose hours a date uses: its own kind's, or on a day of rest done anyway the first with the sunrise.
    func scheduleKind(_ ds: String) -> DayType {
        let t = dayType(ds)
        return t.hasSunrise ? t : firstSunrise
    }

    // MARK: Hours and minutes

    /// Most specific first: this date, this weekday, every day.
    func time(of step: Step, on ds: String?) -> String {
        if let ds {
            if let id = step.id, let t = days[ds]?.times?[id], !t.isEmpty { return t }
            if let times = step.times, let k = Weekday.key(in: times, for: DayKey.weekday(ds)), let t = times[k] { return t }
        }
        return step.time ?? ""
    }

    /// The block that holds a letter on a date when it isn't the sunrise ("5:15 · Gym", "Más tarde · 8:50 pm").
    /// nil when it's in the sunrise, or nothing places it.
    func placement(_ letter: Letter, on ds: String) -> Placement? {
        guard let t = settings.schedule?.type(scheduleKind(ds)), let sunrise = t.sunriseBlockID else { return nil }
        let steps = t[.steps]
        let sunriseAt = steps.firstIndex { $0.id == sunrise } ?? 0
        for (i, st) in steps.enumerated() where st.letterKeys.contains(letter) {
            return st.id == sunrise ? nil : Placement(step: st, time: time(of: st, on: ds), isLater: false, afterSunrise: i > sunriseAt)
        }
        guard let st = t[.later].first(where: { $0.letterKeys.contains(letter) }) else { return nil }
        return Placement(step: st, time: time(of: st, on: ds), isLater: true, afterSunrise: true)
    }

    /// Read comes before Write that day, so Write asks about today's reading, not yesterday's.
    func readsBeforeWriting(_ ds: String) -> Bool {
        let order = blocks(ds).flatMap(\.letters)
        return (order.firstIndex(of: .lectura) ?? .max) < (order.firstIndex(of: .escritura) ?? .max)
    }

    /// "Dormido" (asleep): the night's step that says so, in either language, or its last one.
    func bedStep(_ kind: DayType) -> Step? {
        let night = settings.schedule?.type(kind)?[.night] ?? []
        return night.first { st in ["dorm", "sleep", "bed"].contains { st.title?.localizedCaseInsensitiveContains($0) == true } } ?? night.last
    }

    static let usualWindDown = 45
    /// What Prepararte's wheel offers: 15 to 90, by 5.
    static let windDownChoices = Array(stride(from: 15, through: 90, by: 5))
    /// What Silencio's and Lectura's wheels offer: 1…60, then quarter hours up to two hours.
    static let minuteChoices = Array(1...60) + [75, 90, 105, 120]

    /// How many minutes before "Dormido" "Prepararte para dormir" arrives, the same every night.
    var windDown: Int {
        settings.schedule?.windDown.flatMap { (1...240).contains($0) ? $0 : nil } ?? Self.usualWindDown
    }

    static func valid(_ v: JSONValue?) -> Int? {
        guard let n = v?.number, n >= 1, n <= 240, n.rounded() == n else { return nil }
        return Int(n)
    }

    /// Silencio's and Lectura's minutes: this weekday of the schedule, or all its days, or the usual.
    func usualMinutes(_ kind: DayType, _ letter: Letter, weekday w: Int?) -> Int {
        let t = settings.schedule?.type(kind)
        if let w, let own = t?.minutesDays?[letter.rawValue], let k = Weekday.key(in: own, for: w), let n = Self.valid(own[k]) { return n }
        return Self.valid(t?.minutes?[letter.rawValue]) ?? defaultMinutes(letter)
    }

    /// Breathe's and Read's minutes when the schedule doesn't set them: the sunrise's length decides.
    func defaultMinutes(_ letter: Letter) -> Int {
        settings.length?.minutes(letter) ?? letter.usualMinutes ?? 0
    }

    func minutesOn(_ kind: DayType, _ letter: Letter, on ds: String) -> Int {
        Self.valid(days[ds]?.mins?[letter.rawValue]) ?? usualMinutes(kind, letter, weekday: DayKey.weekday(ds))
    }

    /// How long a letter takes on a date; 0 when it isn't known.
    func letterMinutes(_ letter: Letter, _ kind: DayType, on ds: String) -> Int {
        letter.usualMinutes != nil ? minutesOn(kind, letter, on: ds) : fixedMinutes(letter)
    }

    /// How long a letter usually takes on a weekday (nil: on all the days of its kind).
    func letterMinutes(_ letter: Letter, _ kind: DayType, weekday w: Int?) -> Int {
        letter.usualMinutes != nil ? usualMinutes(kind, letter, weekday: w) : fixedMinutes(letter)
    }

    /// The letters whose minutes come from what's in them, not from a setting.
    private func fixedMinutes(_ letter: Letter) -> Int {
        switch letter {
        case .silencio, .lectura: defaultMinutes(letter)
        case .afirmaciones: max(1, Int((Double(settings.affirmations.filled.count * 25) / 60).rounded(.up)))
        case .visualizacion:
            max(1, Int((Double(settings.visualization.items.filled.count) * (settings.length?.imagineSeconds ?? 60) / 60).rounded(.up)))
        case .ejercicio: Workout.of(settings).minutes
        case .escritura: settings.length?.writeMinutes ?? 2
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
            add(st.id ?? "l\(i)", [String(localized: "Later"), time(of: st, on: ds)], st.letterKeys, isLater: true)
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

    /// Sunrises in a row, complete; days of rest don't break it. If today's isn't done yet, from yesterday.
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

    /// Checked off on some day: its first-time note has done its job.
    func everDone(_ letter: Letter) -> Bool { days.values.contains { $0.isDone(letter) } }

    /// Complete sunrises, ever.
    var sunrisesDone: Int { days.values.count { $0.doneCount == 6 } }

    func affirmationReviewDue(reviewed: String?) -> Bool { reviewed != DayKey.month(today) }
}
