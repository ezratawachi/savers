import Foundation

/// One change from the AI's block, already checked: only what Ajustes lets you do yourself.
struct AIChange: Identifiable {
    enum Edit {
        case readApp(String)
        case affirmations([Item])
        case visualization([Item])
        case visualizationNote(String)
        case windDown(Int)
        case weekType(Int, DayType)
        /// For all the days of its kind (nil weekday), or one weekday; nil time: that weekday follows the rest.
        case stepTime(DayType, stepID: String, weekday: Int?, String?)
        case minutes(DayType, Letter, weekday: Int?, Int?)
        case dateReset(String)
        case dateType(String, DayType)
        /// nil: back to the usual.
        case dateTime(String, stepID: String, String?)
        case dateMinutes(String, Letter, Int?)
    }

    let id: Int
    let edit: Edit
    /// "Sunrise"
    let title: String
    /// "Normal · Thursdays only"
    let context: String
    /// "5:55 → 5:45"
    let detail: String
    /// For a list: "2. “…” (was “…”)", "3. New: “…”".
    var lines: [String] = []

    /// The date it touches, if any.
    var date: String? {
        switch edit {
        case .dateReset(let ds), .dateType(let ds, _), .dateTime(let ds, _, _), .dateMinutes(let ds, _, _): ds
        default: nil
        }
    }

    /// Kinds of days before their hours, all days before one weekday, a date's kind before its hours.
    var order: Int {
        switch edit {
        case .readApp, .affirmations, .visualization, .visualizationNote, .windDown: 0
        case .weekType: 1
        case .stepTime(_, _, let w, _): w == nil ? 2 : 3
        case .minutes(_, _, let w, _): w == nil ? 4 : 5
        case .dateReset: 6
        case .dateType: 7
        case .dateTime, .dateMinutes: 8
        }
    }
}

extension AIChange.Edit {
    /// Applies this change to the settings and the days, the way Ajustes and the day sheet would.
    /// Unlike "All" in Settings, a new hour for all days keeps the weekdays that have their own: the AI
    /// only changes what it names.
    func apply(to s: inout AppSettings, days: inout [String: Day], today: String) {
        switch self {
        case .readApp(let a): s.readApp = a
        case .affirmations(let items): s.affirmations = items
        case .visualization(let items): s.visualization.items = items
        case .visualizationNote(let n): s.visualization.note = n
        case .windDown(let m):
            var sc = s.schedule ?? .blank
            sc.windDown = m
            s.schedule = sc
        case .weekType(let w, let t):
            var sc = s.schedule ?? .blank
            sc.week[String(w)] = t.rawValue
            s.schedule = sc
        case .stepTime(let kind, let id, let w, let time):
            Self.changeStep(&s, kind, id) { st in
                var times = st.times ?? [:]
                if let w {
                    if let k = Weekday.key(in: times, for: w) { times[k] = nil }
                    if let time, !TimeText.same(time, st.time) { times[Weekday.keys[w]] = time }
                } else if let time {
                    st.time = time
                    for (k, v) in times where TimeText.same(v, time) { times[k] = nil }
                }
                st.times = times.isEmpty ? nil : times
            }
        case .minutes(let kind, let letter, let w, let n):
            guard var t = s.schedule?.types?[kind.rawValue] else { return }
            let key = letter.rawValue
            var perDay = t.minutesDays ?? [:]
            var own = perDay[key] ?? [:]
            if let w {
                if let k = Weekday.key(in: own, for: w) { own[k] = nil }
                let all = Routine.valid(t.minutes?[key]) ?? letter.usualMinutes
                if let n, n != all { own[Weekday.keys[w]] = .number(Double(n)) }
            } else if let n {
                var all = t.minutes ?? [:]
                all[key] = .number(Double(n))
                t.minutes = all
                for (k, v) in own where Routine.valid(v) == n { own[k] = nil }
            }
            perDay[key] = own.isEmpty ? nil : own
            t.minutesDays = perDay.isEmpty ? nil : perDay
            s.schedule?.types?[kind.rawValue] = t
        case .dateReset(let ds):
            Self.changeDay(&days, ds) { d in
                d.type = nil
                d.times = nil
                d.mins = nil
            }
        case .dateType(let ds, let type):
            let usual = Routine(settings: s, days: days, today: today).weekDayType(ds)
            Self.changeDay(&days, ds) { $0.type = type == usual ? nil : type.rawValue }
        case .dateTime(let ds, let id, let time):
            let r = Routine(settings: s, days: days, today: today)
            guard let st = r.step(r.dayType(ds), id: id) else { return }
            let usual = r.usualTime(st, weekday: DayKey.weekday(ds))
            Self.changeDay(&days, ds) { d in
                var times = d.times ?? [:]
                times[id] = time.flatMap { TimeText.same($0, usual) ? nil : $0 }
                d.times = times.isEmpty ? nil : times
            }
        case .dateMinutes(let ds, let letter, let n):
            let r = Routine(settings: s, days: days, today: today)
            let usual = r.usualMinutes(r.scheduleKind(ds), letter, weekday: DayKey.weekday(ds))
            Self.changeDay(&days, ds) { d in
                var mins = d.mins ?? [:]
                mins[letter.rawValue] = n.flatMap { $0 == usual ? nil : .number(Double($0)) }
                d.mins = mins.isEmpty ? nil : mins
            }
        }
    }

    private static func changeStep(_ s: inout AppSettings, _ kind: DayType, _ id: String, _ body: (inout Step) -> Void) {
        guard var t = s.schedule?.types?[kind.rawValue] else { return }
        for g in TypeSchedule.Group.allCases {
            var list = t[g]
            guard let i = list.firstIndex(where: { $0.id == id }) else { continue }
            body(&list[i])
            t[g] = list
        }
        s.schedule?.types?[kind.rawValue] = t
    }

    private static func changeDay(_ days: inout [String: Day], _ ds: String, _ body: (inout Day) -> Void) {
        var d = days[ds] ?? Day(date: ds)
        body(&d)
        days[ds] = d
    }
}
