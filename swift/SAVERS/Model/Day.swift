import Foundation

/// One date's record: `savers:days["AAAA-MM-DD"]` and `users/{uid}/days/{fecha}.day`.
struct Day: Codable, Equatable, Sendable {
    var date: String
    var checks: [String: Bool] = [:]
    var gratitude = ""
    var bookIdea = ""
    var notes = ""
    /// SAVERS done on a "Sin SAVERS" day.
    var extra = false
    /// Set on every change; the newest wins a conflict.
    var updatedAt: String?
    /// This date is another kind of day than its weekday (only when it differs).
    var type: String?
    /// An hour for this date only, by step id.
    var times: [String: String]?
    /// Minutes for this date only: `{"lectura": 30}`.
    var mins: [String: JSONValue]?
    /// When each marked letter was marked: `{"lectura": "2026-10-01T01:40:00.000Z"}`.
    var checkedAt: [String: String]?
    var extras: [String: JSONValue] = [:]

    private static let known: Set<String> = ["date", "checks", "gratitude", "bookIdea", "notes", "extra", "updatedAt", "type", "times", "mins", "checkedAt"]
    /// Fields of an old version ("gran día"), dropped with what was written in them.
    private static let dropped: Set<String> = ["priorities", "prioDone"]

    init(date: String) { self.date = date }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        date = c.lenient(String.self, "date") ?? ""
        checks = c.lenient([String: Bool].self, "checks") ?? [:]
        gratitude = c.lenient(String.self, "gratitude") ?? ""
        bookIdea = c.lenient(String.self, "bookIdea") ?? ""
        notes = c.lenient(String.self, "notes") ?? ""
        extra = c.lenient(Bool.self, "extra") ?? false
        updatedAt = c.lenient(String.self, "updatedAt")
        type = c.lenient(String.self, "type")
        times = c.lenient([String: JSONValue].self, "times")?.compactMapValues(\.text)
        mins = c.lenient([String: JSONValue].self, "mins")
        checkedAt = c.lenient([String: String].self, "checkedAt")
        extras = c.extras(excluding: Self.known.union(Self.dropped))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        try c.encodeExtras(extras)
        try c.encode(date, forKey: AnyKey("date"))
        try c.encode(checks, forKey: AnyKey("checks"))
        try c.encode(gratitude, forKey: AnyKey("gratitude"))
        try c.encode(bookIdea, forKey: AnyKey("bookIdea"))
        try c.encode(notes, forKey: AnyKey("notes"))
        try c.encode(extra, forKey: AnyKey("extra"))
        try c.encodeIfPresent(updatedAt, forKey: AnyKey("updatedAt"))
        try c.encodeIfPresent(type, forKey: AnyKey("type"))
        try c.encodeIfPresent(times, forKey: AnyKey("times"))
        try c.encodeIfPresent(mins, forKey: AnyKey("mins"))
        try c.encodeIfPresent(checkedAt, forKey: AnyKey("checkedAt"))
    }

    func isDone(_ letter: Letter) -> Bool { checks[letter.rawValue] == true }

    var doneCount: Int { Letter.allCases.count(where: isDone) }

    /// A letter marked or something written.
    var hasContent: Bool { doneCount > 0 || !gratitude.isEmpty || !bookIdea.isEmpty || !notes.isEmpty }

    subscript(field: WritingField) -> String {
        get {
            switch field {
            case .gratitude: gratitude
            case .bookIdea: bookIdea
            case .notes: notes
            }
        }
        set {
            switch field {
            case .gratitude: gratitude = newValue
            case .bookIdea: bookIdea = newValue
            case .notes: notes = newValue
            }
        }
    }
}
