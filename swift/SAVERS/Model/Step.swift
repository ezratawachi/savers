import Foundation

/// One line of the schedule: "5:20 · Te paras". A step with `letters` is a block holding those letters.
struct Step: Codable, Equatable, Identifiable, Sendable {
    var id: String?
    var title: String?
    var short: String?
    var detail: String?
    /// "5:20" (morning), "10:10 pm", "12:10 am".
    var time: String?
    /// Other hours on some weekdays: `{"jue": "5:10"}`.
    var times: [String: String]?
    var letters: [String]?
    var extras: [String: JSONValue] = [:]

    private static let known: Set<String> = ["id", "title", "short", "detail", "time", "times", "letters"]

    init(id: String, title: String, time: String, letters: [String]) {
        self.id = id
        self.title = title
        self.time = time
        self.letters = letters
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        id = c.lenient(String.self, "id")
        title = c.lenient(String.self, "title")
        short = c.lenient(String.self, "short")
        detail = c.lenient(String.self, "detail")
        time = c.lenient(JSONValue.self, "time")?.text
        times = c.lenient([String: JSONValue].self, "times")?.compactMapValues(\.text)
        letters = c.lenient([String].self, "letters")
        extras = c.extras(excluding: Self.known)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        try c.encodeExtras(extras)
        try c.encodeIfPresent(id, forKey: AnyKey("id"))
        try c.encodeIfPresent(title, forKey: AnyKey("title"))
        try c.encodeIfPresent(short, forKey: AnyKey("short"))
        try c.encodeIfPresent(detail, forKey: AnyKey("detail"))
        try c.encodeIfPresent(time, forKey: AnyKey("time"))
        try c.encodeIfPresent(times, forKey: AnyKey("times"))
        try c.encodeIfPresent(letters, forKey: AnyKey("letters"))
    }

    /// The name shown in a block's heading.
    var label: String { short.flatMap { $0.isEmpty ? nil : $0 } ?? title ?? "" }

    /// The letters this step holds, known ones only, in its order.
    var letterKeys: [Letter] { (letters ?? []).compactMap(Letter.init(rawValue:)) }

    /// The one step it holds, when the block is named after it: "Read", "Lee", or "Lectura" from before.
    var onlyStep: Letter? {
        guard letterKeys.count == 1, let k = letterKeys.first, let title else { return nil }
        let plain = { (s: String) in s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil) }
        return k.knownNames.contains { plain(title).caseInsensitiveCompare(plain($0)) == .orderedSame } ? k : nil
    }
}
