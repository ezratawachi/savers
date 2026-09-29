import Foundation

/// The settings and the days as JSON files on this iPhone, in the same format as the web's localStorage.
struct Persistence {
    let folder: URL

    static let standard = Persistence(folder: URL.applicationSupportDirectory.appending(path: "savers", directoryHint: .isDirectory))

    private var settingsURL: URL { folder.appending(path: "settings.json") }
    private var daysURL: URL { folder.appending(path: "days.json") }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return e
    }()

    func load() -> (settings: AppSettings?, days: [String: Day]) {
        let d = JSONDecoder()
        let settings = (try? Data(contentsOf: settingsURL)).flatMap { try? d.decode(AppSettings.self, from: $0) }
        var days: [String: Day] = [:]
        if let data = try? Data(contentsOf: daysURL), let raw = try? d.decode([String: JSONValue].self, from: data) {
            days = Self.days(from: raw)
        }
        return (settings, days)
    }

    /// Each day on its own, so one odd day never loses the rest.
    static func days(from raw: [String: JSONValue]) -> [String: Day] {
        var out: [String: Day] = [:]
        for (ds, v) in raw where DayKey.isValid(ds) {
            guard case .object = v, let data = try? encoder.encode(v), var day = try? JSONDecoder().decode(Day.self, from: data) else { continue }
            if day.date.isEmpty { day.date = ds }
            out[ds] = day
        }
        return out
    }

    func save(settings: AppSettings, days: [String: Day]) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Self.encoder.encode(settings).write(to: settingsURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try Self.encoder.encode(days).write(to: daysURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
