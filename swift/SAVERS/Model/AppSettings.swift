import Foundation

/// `savers:settings` and `users/{uid}/meta/settings.settings`. Reading it does what the web's
/// `normalizeSettings` does: fills defaults, accepts plain strings in lists, drops old fields and notes.
struct AppSettings: Codable, Equatable, Sendable {
    var name: String = ""
    var affirmations: [Item] = [Item(text: "")]
    var visualization: Visualization = .standard
    var schedule: Schedule?
    var readApp: String = "libros"

    static let readApps = ["libros", "kindle", "papel"]

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
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        try c.encode(name, forKey: AnyKey("name"))
        try c.encode(affirmations, forKey: AnyKey("affirmations"))
        try c.encode(visualization, forKey: AnyKey("visualization"))
        // The web keeps `"schedule": null` when there's none.
        if let schedule { try c.encode(schedule, forKey: AnyKey("schedule")) } else { try c.encodeNil(forKey: AnyKey("schedule")) }
        try c.encode(readApp, forKey: AnyKey("readApp"))
    }

    /// Name, a schedule or an affirmation: something that came from a copy or the cloud.
    var hasPersonalData: Bool { !name.isEmpty || schedule != nil || !affirmations.filled.isEmpty }
}
