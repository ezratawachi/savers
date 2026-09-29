import Foundation

/// The weekly schedule. Fields it doesn't use (the legacy `table`, `timelineNormal`, `timelineGym`, `note`…)
/// ride along in `extras` so the web still finds them.
struct Schedule: Codable, Equatable, Sendable {
    /// "0" (Sunday) … "5" (Friday) → "normal" | "gym" | "off". Saturday is always Shabbat.
    var week: [String: String] = [:]
    var gymTime: String?
    var gymReading: String?
    var types: [String: TypeSchedule]?
    var extras: [String: JSONValue] = [:]

    private static let known: Set<String> = ["week", "gymTime", "gymReading", "types"]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        week = c.lenient([String: String].self, "week") ?? [:]
        gymTime = c.lenient(String.self, "gymTime")
        gymReading = c.lenient(String.self, "gymReading")
        types = c.lenient([String: TypeSchedule].self, "types")
        extras = c.extras(excluding: Self.known)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        try c.encodeExtras(extras)
        try c.encode(week, forKey: AnyKey("week"))
        try c.encodeIfPresent(gymTime, forKey: AnyKey("gymTime"))
        try c.encodeIfPresent(gymReading, forKey: AnyKey("gymReading"))
        try c.encodeIfPresent(types, forKey: AnyKey("types"))
    }

    func type(_ kind: DayType) -> TypeSchedule? { types?[kind.rawValue] }

    /// The web's `migrateSchedule`: older schedules said `"days": "lun, mar"` in each type and had no ids.
    /// This brings them to the week map, gives every step an id and a time for all days.
    mutating func migrate() {
        let old = week
        var w: [String: String] = [:]
        for (k, v) in DayType.defaultWeek { w[String(k)] = v.rawValue }
        if !old.isEmpty {
            for k in w.keys { if let t = old[k], DayType.choosable.map(\.rawValue).contains(t) { w[k] = t } }
        } else if let types {
            for kind in ["normal", "gym"] {
                guard case .string(let days)? = types[kind]?.extras["days"] else { continue }
                for d in Weekday.parseList(days) where d != 6 { w[String(d)] = kind }
            }
        }
        week = w
        guard var types else { return }
        var used: Set<String> = []
        for kind in ["normal", "gym"] {
            guard var t = types[kind] else { continue }
            t.extras["days"] = nil
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
            types[kind] = t
        }
        self.types = types
    }
}
