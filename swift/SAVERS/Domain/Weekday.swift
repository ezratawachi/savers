import Foundation

/// Weekdays as the schedule writes them: 0 = Sunday … 6 = Saturday, keys "dom" … "sáb". What's shown comes
/// from the app's language.
enum Weekday {
    /// How the data names them, in any language: never shown.
    static let keys = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"]
    /// "domingo", "Sunday"
    static let names: [String] = (symbols.standaloneWeekdaySymbols ?? []).map { AppLanguage.isSpanish ? $0.lowercased() : $0 }
    /// "dom", "Sun"
    static let short: [String] = symbols.shortStandaloneWeekdaySymbols ?? keys
    /// The calendar's column heads.
    static let letters: [String] = symbols.veryShortStandaloneWeekdaySymbols ?? []

    private static var symbols: DateFormatter {
        let f = DateFormatter()
        f.locale = AppLanguage.locale
        return f
    }

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

    /// "los jueves", "Thursdays"
    static func plural(_ w: Int) -> String {
        let n = names[w]
        guard AppLanguage.isSpanish else { return n + "s" }
        return "los " + n + (n.hasSuffix("s") ? "" : "s")
    }

    /// "los lunes y los jueves"
    static func plurals(_ ws: [Int]) -> String { AppLanguage.list(ws.map(plural)) }

    /// "lun, mar, jue"
    static func list(_ ws: [Int]) -> String { ws.map { short[$0] }.joined(separator: ", ") }
}
