import Foundation

/// What only this iPhone keeps (never in a copy or the cloud), under the web's own key names.
struct LocalPrefs {
    let defaults: UserDefaults

    static let standard = LocalPrefs(defaults: .standard)

    subscript(key: String) -> String? {
        get { defaults.string(forKey: "savers:" + key) }
        nonmutating set { defaults.set(newValue, forKey: "savers:" + key) }
    }
}

extension Date {
    /// Like JavaScript's `toISOString()`: "2026-09-29T11:02:03.456Z".
    var iso: String { formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)) }

    init?(iso: String?) {
        guard let iso else { return nil }
        if let d = try? Date(iso, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) { self = d }
        else if let d = try? Date(iso, strategy: .iso8601) { self = d }
        else { return nil }
    }
}
