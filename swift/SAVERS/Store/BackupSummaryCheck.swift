import Foundation

extension Backup {
    /// What the file's summary says that importing won't keep: "Afirmaciones a las 6:10 (lun, mar)".
    /// A summary that still shows the routine as it was, or as it will be after importing, is fine.
    func summaryChanges(current: AppSettings) -> [String] {
        guard !resumen.isEmpty else { return [] }
        var merged = current
        for part in parts {
            switch part {
            case .name: merged.name = settings.name
            case .affirmations: merged.affirmations = settings.affirmations
            case .visualization: merged.visualization = settings.visualization
            case .schedule: merged.schedule = settings.schedule
            }
        }
        let before = Routine(settings: current, days: [:], today: "").weekSummary()
        let after = Routine(settings: merged, days: [:], today: "").weekSummary()
        var found: [String: [String]] = [:]
        var order: [String] = []

        // Weekday by weekday, so the lists read in the week's order however the file wrote its keys.
        for w in 0...6 {
            let key = Weekday.plain(Weekday.names[w])
            guard let theirs = resumen.first(where: { Weekday.plain($0.key) == key })?.value,
                  let ours = Self.letters(after[Weekday.names[w]]),
                  case .object(let t) = theirs, case .array(let theirLetters)? = t["letras"] else { continue }
            let was = Self.letters(before[Weekday.names[w]]) ?? []
            for case .object(let x) in theirLetters {
                let name = Self.plain(x["letra"]?.text)
                guard let m = ours.first(where: { Self.plain($0["letra"]?.text) == name }) else { continue }
                let o = was.first { Self.plain($0["letra"]?.text) == name } ?? [:]
                let h = (x["hora"]?.text ?? "").trimmingCharacters(in: .whitespaces)
                let mn = x["minutos"]?.number
                let letter = m["letra"]?.text ?? ""
                var what = ""
                if let mh = m["hora"]?.text, !mh.isEmpty, !h.isEmpty,
                   !TimeText.same(h, mh), !TimeText.same(h, o["hora"]?.text) {
                    what = "\(letter) a las \(h)"
                } else if let mn, mn != m["minutos"]?.number, mn != o["minutos"]?.number {
                    what = "\(letter) en \(mn.formatted()) min"
                }
                guard !what.isEmpty else { continue }
                if found[what] == nil { order.append(what) }
                found[what, default: []].append(Weekday.keys[w])
            }
        }
        return order.map { "\($0) (\(found[$0, default: []].joined(separator: ", ")))" }
    }

    private static func letters(_ v: JSONValue?) -> [[String: JSONValue]]? {
        guard case .object(let o)? = v, case .array(let a)? = o["letras"] else { return nil }
        return a.compactMap { if case .object(let x) = $0 { x } else { nil } }
    }

    private static func plain(_ s: String?) -> String {
        (s ?? "").folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).trimmingCharacters(in: .whitespaces)
    }
}
