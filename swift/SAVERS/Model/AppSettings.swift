import Foundation

/// `savers:settings` and `users/{uid}/meta/settings.settings`. Reading it does what the web's
/// `normalizeSettings` does: fills defaults, accepts plain strings in lists, drops old fields and notes.
struct AppSettings: Codable, Equatable, Sendable {
    var name: String = ""
    var affirmations: [Item] = [Item(text: "")]
    var visualization: Visualization = .standard
    var schedule: Schedule?
    var readApp: String = "libros"
    /// "Notas para la IA": what the app doesn't know (work, what never moves, goals). Always in the packet.
    var aiNotes: String = ""
    /// 10, 20 or 30 minutes, chosen on the first open. None on copies from before: the usual minutes.
    var length: SunriseLength?

    static let readApps = ["libros", "kindle", "papel"]

    /// Phrases someone can believe from the first day, to edit until they're theirs: about choosing and
    /// practicing, never "I'm amazing".
    static var exampleAffirmations: [Item] {
        [
            Item(text: String(localized: "Today I choose to start calmly.")),
            Item(text: String(localized: "I'm learning to keep the promises I make to myself, one at a time.")),
            Item(text: String(localized: "I can do what matters today, even if it isn't perfect.")),
        ]
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        if let n = c.lenient(String.self, "name") { name = n }
        if let a = c.lenient([Item].self, "affirmations"), !a.isEmpty { affirmations = a }
        if let v = c.lenient(Visualization.self, "visualization") { visualization = v }
        if var s = c.lenient(Schedule.self, "schedule") {
            s.migrate()
            schedule = s
        }
        if let r = c.lenient(String.self, "readApp"), Self.readApps.contains(r) { readApp = r }
        if let n = c.lenient(String.self, "aiNotes") { aiNotes = n }
        length = c.lenient(SunriseLength.self, "length")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        try c.encode(name, forKey: AnyKey("name"))
        try c.encode(affirmations, forKey: AnyKey("affirmations"))
        try c.encode(visualization, forKey: AnyKey("visualization"))
        // The web keeps `"schedule": null` when there's none.
        if let schedule { try c.encode(schedule, forKey: AnyKey("schedule")) } else { try c.encodeNil(forKey: AnyKey("schedule")) }
        try c.encode(readApp, forKey: AnyKey("readApp"))
        if !aiNotes.isEmpty { try c.encode(aiNotes, forKey: AnyKey("aiNotes")) }
        try c.encodeIfPresent(length, forKey: AnyKey("length"))
    }

    /// Name, a schedule or an affirmation: something that came from a copy or the cloud.
    var hasPersonalData: Bool { !name.isEmpty || schedule != nil || !affirmations.filled.isEmpty }
}
