import Foundation

/// Weekdays as the schedule writes them: 0 = Sunday … 6 = Saturday, keys "dom" … "sáb".
enum Weekday {
    static let keys = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"]
    static let names = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    /// The calendar's column heads.
    static let letters = ["D", "L", "M", "M", "J", "V", "S"]

    /// "Mié", "miercoles", "MIE." → "mie": how two day keys are compared.
    static func plain(_ s: String) -> String {
        String(s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased().prefix(3))
    }

    /// "lun, mar, jue" → [1, 2, 4]
    static func parseList(_ s: String) -> [Int] {
        let plainKeys = keys.map(plain)
        return s.split(whereSeparator: { $0 == "," || $0.isWhitespace })
            .compactMap { plainKeys.firstIndex(of: plain(String($0))) }
    }

    /// The key in `dict` that means weekday `w`, however it's written.
    static func key<V>(in dict: [String: V], for w: Int) -> String? {
        let p = plain(keys[w])
        return dict.keys.first { plain($0) == p }
    }

    /// "los jueves", "los domingos"
    static func plural(_ w: Int) -> String {
        let n = names[w]
        return "los " + n + (n.hasSuffix("s") ? "" : "s")
    }

    /// "los lunes y los jueves"
    static func plurals(_ ws: [Int]) -> String { ws.map(plural).joined(separator: " y ") }

    /// "lun, mar, jue"
    static func list(_ ws: [Int]) -> String { ws.map { keys[$0] }.joined(separator: ", ") }
}
