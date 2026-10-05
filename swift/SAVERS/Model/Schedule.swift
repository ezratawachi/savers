import Foundation

/// The weekly schedule: the kinds of day and what each weekday is. Fields it doesn't use (the legacy `table`,
/// `timelineNormal`, `gymTime`, `gymReading`…) ride along in `extras`, so nothing of yours is lost.
struct Schedule: Codable, Equatable, Sendable {
    /// "0" (Sunday) … "6" (Saturday) → a kind's id.
    var week: [String: String] = [:]
    /// The weeks before the last changes, so the past never changes.
    var pastWeeks: [PastWeek]?
    /// Minutes before "Dormido" (asleep) that "Prepararte para dormir" (wind down) arrives, the same every night.
    var windDown: Int?
    /// Every kind of day by id, the deleted ones too.
    var types: [String: TypeSchedule]?
    var extras: [String: JSONValue] = [:]

    private static let known: Set<String> = ["week", "pastWeeks", "windDown", "types"]

    /// A schedule that only says what each weekday is (the web's `migrateSchedule({})`).
    static var blank: Schedule {
        var s = Schedule()
        s.migrate()
        return s
    }

    private init() {}

    /// Someone new: Normal every day, with the sunrise as the morning's only block when they wake up, and Rest.
    static func starter(wake: String) -> Schedule {
        var s = Schedule()
        s.week = Dictionary(uniqueKeysWithValues: (0...6).map { (String($0), DayType.normal) })
        var normal = TypeSchedule()
        normal.order = 0
        normal.steps = [Step(id: "normal-steps-0", title: String(localized: "Sunrise"), time: wake, letters: Letter.allCases.map(\.rawValue))]
        normal.sunrise = "normal-steps-0"
        var rest = TypeSchedule()
        rest.order = 1
        rest.rest = true
        s.types = [DayType.normal: normal, DayType.rest: rest]
        return s
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        week = c.lenient([String: String].self, "week") ?? [:]
        pastWeeks = c.lenient([PastWeek].self, "pastWeeks")
        windDown = c.lenient(Int.self, "windDown")
        types = c.lenient([String: TypeSchedule].self, "types")
        extras = c.extras(excluding: Self.known)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        try c.encodeExtras(extras)
        try c.encode(week, forKey: AnyKey("week"))
        try c.encodeIfPresent(pastWeeks, forKey: AnyKey("pastWeeks"))
        try c.encodeIfPresent(windDown, forKey: AnyKey("windDown"))
        try c.encodeIfPresent(types, forKey: AnyKey("types"))
    }

    func type(_ kind: DayType) -> TypeSchedule? { types?[kind.id] }

    /// What each weekday was on a date: the week in force then. From today on, the one you have now.
    func week(on ds: String, today: String) -> [String: String] {
        guard ds < today else { return week }
        return (pastWeeks ?? []).filter { $0.until >= ds }.min { $0.until < $1.until }?.week ?? week
    }

    /// A weekday becomes another kind from today on; the days before keep the week they had.
    mutating func setWeek(_ w: Int, to id: String, today: String) {
        guard week[String(w)] != id else { return }
        let until = DayKey.adding(-1, to: today)
        var past = pastWeeks ?? []
        // Changed earlier today: the week before today is already kept.
        if !past.contains(where: { $0.until >= until }) { past.append(PastWeek(until: until, week: week)) }
        pastWeeks = past
        week[String(w)] = id
    }

    /// Brings anything older to how kinds are kept now. Before kinds were your own the web's `migrateSchedule`
    /// set the week, Saturday was always Shabbat and the kinds were only Normal and Gym: those become kinds like
    /// any other, with the same ids (Rest is "off"), so the dates that say them still do. Every step gets an id
    /// and a time for all days, and every kind with the sunrise says which block it is. Safe to run again.
    mutating func migrate() {
        var types = self.types ?? [:]
        if week["6"] == nil {
            let old = week
            let usual = [DayType.rest, DayType.normal, DayType.normal, DayType.gym, DayType.normal, DayType.gym]
            var w: [String: String] = [:]
            for (i, id) in usual.enumerated() { w[String(i)] = id }
            if !old.isEmpty {
                for k in w.keys { if let t = old[k], [DayType.normal, DayType.gym, DayType.rest].contains(t) { w[k] = t } }
            } else {
                for kind in [DayType.normal, DayType.gym] {
                    guard case .string(let days)? = types[kind]?.extras["days"] else { continue }
                    for d in Weekday.parseList(days) where d != 6 { w[String(d)] = kind }
                }
            }
            w["6"] = DayType.shabbat
            week = w
            if var normal = types[DayType.normal] {
                normal.order = normal.order ?? 0
                types[DayType.normal] = normal
            }
            if var gym = types[DayType.gym] {
                gym.order = gym.order ?? 1
                gym.name = gym.name ?? "Gym"
                types[DayType.gym] = gym
            }
            for (i, id) in [DayType.rest, DayType.shabbat].enumerated() where types[id] == nil {
                var t = TypeSchedule()
                t.rest = true
                t.order = 2 + i
                if id == DayType.shabbat { t.name = "Shabbat" }
                types[id] = t
            }
        }
        // Old kinds first, so their ids win as they always did.
        let oldKinds = [DayType.normal, DayType.gym]
        let ids = oldKinds + types.keys.filter { !oldKinds.contains($0) }.sorted()
        var used: Set<String> = []
        var next = (types.values.compactMap(\.order).max() ?? -1) + 1
        for kind in ids {
            guard var t = types[kind] else { continue }
            t.extras["days"] = nil
            if t.order == nil {
                t.order = next
                next += 1
            }
            for group in TypeSchedule.Group.allCases {
                var list = t[group]
                for i in list.indices {
                    var st = list[i]
                    if st.id.map({ $0.isEmpty || used.contains($0) }) ?? true { st.id = "\(kind)-\(group.rawValue)-\(i)" }
                    used.insert(st.id ?? "")
                    if var times = st.times {
                        if (st.time ?? "").isEmpty, let first = times.keys.sorted().first { st.time = times[first] }
                        for (k, v) in times where TimeText.same(v, st.time) { times[k] = nil }
                        st.times = times.isEmpty ? nil : times
                    }
                    list[i] = st
                }
                t[group] = list
            }
            if t.rest != true, t.sunrise == nil { t.sunrise = t.sunriseBlockID }
            types[kind] = t
        }
        self.types = types.isEmpty ? nil : types
    }

    /// The morning block that held the letters was called "SAVERS"; it's "Sunrise" ("Amanecer") now. Done once, on what
    /// arrives from this iPhone or the cloud. Returns whether anything changed.
    mutating func renameSaversBlock() -> Bool {
        guard var types else { return false }
        var changed = false
        for (kind, var t) in types {
            guard var list = t.steps else { continue }
            for i in list.indices where !list[i].letterKeys.isEmpty {
                for field in [\Step.title, \Step.short] where list[i][keyPath: field]?.lowercased() == "savers" {
                    list[i][keyPath: field] = String(localized: "Sunrise")
                    changed = true
                }
            }
            t.steps = list
            types[kind] = t
        }
        if changed { self.types = types }
        return changed
    }
}
