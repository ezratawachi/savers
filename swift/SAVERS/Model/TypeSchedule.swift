/// One kind of day: its name, whether it has the sunrise, and the hours of one that does.
struct TypeSchedule: Codable, Equatable, Sendable {
    enum Group: String, CaseIterable, Sendable {
        case night, steps, later
    }

    /// nil: the app's own name ("Normal", "Rest").
    var name: String?
    /// A day of rest: no sunrise, no hours.
    var rest: Bool?
    /// When it was made, 0 for the first: the oldest is the one used when a day needs some kind.
    var order: Int?
    /// Removed from the list, kept for the days that were this kind.
    var deleted: Bool?
    /// The id of the block that is the sunrise; the other blocks can hold steps too.
    var sunrise: String?
    var night: [Step]?
    var steps: [Step]?
    var later: [Step]?
    /// Silencio's and Lectura's minutes on all days of this kind: `{"silencio": 10}`.
    var minutes: [String: JSONValue]?
    /// On one weekday only: `{"lectura": {"jue": 10}}`.
    var minutesDays: [String: [String: JSONValue]]?
    var extras: [String: JSONValue] = [:]

    private static let known: Set<String> = ["name", "rest", "order", "deleted", "sunrise", "night", "steps", "later", "minutes", "minutesDays"]

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        name = c.lenient(String.self, "name")
        rest = c.lenient(Bool.self, "rest")
        order = c.lenient(Int.self, "order")
        deleted = c.lenient(Bool.self, "deleted")
        sunrise = c.lenient(String.self, "sunrise")
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
        try c.encodeIfPresent(name, forKey: AnyKey("name"))
        try c.encodeIfPresent(rest, forKey: AnyKey("rest"))
        try c.encodeIfPresent(order, forKey: AnyKey("order"))
        try c.encodeIfPresent(deleted, forKey: AnyKey("deleted"))
        try c.encodeIfPresent(sunrise, forKey: AnyKey("sunrise"))
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
    /// The sunrise's own block: the one it says, or (from before it said) the morning one holding the most steps.
    var sunriseBlockID: String? {
        if let sunrise, (steps ?? []).contains(where: { $0.id == sunrise }) { return sunrise }
        return (steps ?? []).filter { !$0.letterKeys.isEmpty }.max { $0.letterKeys.count < $1.letterKeys.count }?.id
    }
}
