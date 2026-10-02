/// The hours of one kind of day (normal or gym).
struct TypeSchedule: Codable, Equatable, Sendable {
    enum Group: String, CaseIterable, Sendable {
        case night, steps, later
    }

    var night: [Step]?
    var steps: [Step]?
    var later: [Step]?
    /// Silencio's and Lectura's minutes on all days of this kind: `{"silencio": 10}`.
    var minutes: [String: JSONValue]?
    /// On one weekday only: `{"lectura": {"jue": 10}}`.
    var minutesDays: [String: [String: JSONValue]]?
    var extras: [String: JSONValue] = [:]

    private static let known: Set<String> = ["night", "steps", "later", "minutes", "minutesDays"]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        night = c.lenient([Step].self, "night")
        steps = c.lenient([Step].self, "steps")
        later = c.lenient([Step].self, "later")
        minutes = c.lenient([String: JSONValue].self, "minutes")
        minutesDays = c.lenient([String: [String: JSONValue]].self, "minutesDays")
        extras = c.extras(excluding: Self.known)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        try c.encodeExtras(extras)
        try c.encodeIfPresent(night, forKey: AnyKey("night"))
        try c.encodeIfPresent(steps, forKey: AnyKey("steps"))
        try c.encodeIfPresent(later, forKey: AnyKey("later"))
        try c.encodeIfPresent(minutes, forKey: AnyKey("minutes"))
        try c.encodeIfPresent(minutesDays, forKey: AnyKey("minutesDays"))
    }

    subscript(group: Group) -> [Step] {
        get {
            switch group {
            case .night: night ?? []
            case .steps: steps ?? []
            case .later: later ?? []
            }
        }
        set {
            switch group {
            case .night: if night != nil || !newValue.isEmpty { night = newValue }
            case .steps: if steps != nil || !newValue.isEmpty { steps = newValue }
            case .later: if later != nil || !newValue.isEmpty { later = newValue }
            }
        }
    }
}

extension TypeSchedule {
    /// The sunrise's own block: the morning one holding the most steps (on a gym day, not the gym).
    var sunriseBlockID: String? {
        (steps ?? []).filter { !$0.letterKeys.isEmpty }.max { $0.letterKeys.count < $1.letterKeys.count }?.id
    }
}
