import Foundation

/// Making, renaming and removing kinds of day, and the blocks of one with the sunrise.
extension Schedule {
    /// What a new kind starts as.
    enum Start: Hashable {
        /// One block, the sunrise, with the six steps.
        case sunrise
        /// A day of rest: a name and nothing else.
        case rest
        /// The same as a kind you have, under another name.
        case copy(String)
    }

    /// A new kind at the end of the list; returns its id. `wake` is the sunrise's hour when it starts with one.
    mutating func addKind(named name: String, from start: Start, wake: String) -> String {
        var types = self.types ?? [:]
        var id = Self.newKindID()
        while types[id] != nil { id = Self.newKindID() }
        var t = TypeSchedule()
        switch start {
        case .rest:
            t.rest = true
        case .sunrise:
            let block = "\(id)-steps-0"
            t.steps = [Step(id: block, title: String(localized: "Sunrise"), time: wake, letters: Letter.allCases.map(\.rawValue))]
            t.sunrise = block
        case .copy(let from):
            t = types[from] ?? t
            t.deleted = nil
            // Its own step ids: a date's own hours are kept by step id, and they stay this kind's.
            var renamed: [String: String] = [:]
            for g in TypeSchedule.Group.allCases {
                t[g] = t[g].enumerated().map { i, st in
                    var st = st
                    let new = "\(id)-\(g.rawValue)-\(i)"
                    if let old = st.id { renamed[old] = new }
                    st.id = new
                    return st
                }
            }
            t.sunrise = t.sunrise.flatMap { renamed[$0] }
        }
        t.name = name
        t.order = (types.values.compactMap(\.order).max() ?? -1) + 1
        types[id] = t
        self.types = types
        return id
    }

    private static func newKindID() -> String { "kind-" + UUID().uuidString.prefix(8).lowercased() }

    mutating func renameKind(_ id: String, to name: String) {
        types?[id]?.name = name
    }

    /// Out of the list from today on: the weekdays that were it become `fallback`, and the days that passed keep
    /// their name.
    mutating func deleteKind(_ id: String, fallback: String, today: String) {
        for w in 0...6 where week[String(w)] == id { setWeek(w, to: fallback, today: today) }
        types?[id]?.deleted = true
    }

    // MARK: Blocks

    /// A new block in a kind, where its hour puts it; returns its id.
    mutating func addBlock(_ kind: String, group: TypeSchedule.Group, title: String, time: String) -> String? {
        guard var t = types?[kind] else { return nil }
        let used = Set((types ?? [:]).values.flatMap { t in TypeSchedule.Group.allCases.flatMap { t[$0].compactMap(\.id) } })
        var n = t[group].count
        while used.contains("\(kind)-\(group.rawValue)-\(n)") { n += 1 }
        let id = "\(kind)-\(group.rawValue)-\(n)"
        var st = Step(id: id, title: title, time: time, letters: [])
        st.letters = nil
        t[group] = t[group] + [st]
        t.place(id)
        types?[kind] = t
        return id
    }

    /// Its name everywhere: the short one it had for Hoy goes too.
    mutating func renameBlock(_ kind: String, id: String, to title: String) {
        changeBlock(kind, id: id) { st in
            st.title = title
            st.short = nil
        }
    }

    /// The steps it held go back to the sunrise's block. The sunrise's own block stays.
    mutating func removeBlock(_ kind: String, id: String) {
        guard var t = types?[kind], let sunrise = t.sunriseBlockID, id != sunrise else { return }
        let held = TypeSchedule.Group.allCases.lazy.flatMap { t[$0] }.first { $0.id == id }?.letterKeys ?? []
        for g in TypeSchedule.Group.allCases { t[g] = t[g].filter { $0.id != id } }
        types?[kind] = t
        for l in held { moveStep(l, in: kind, to: sunrise) }
    }

    /// A step lives in one block of a kind: it leaves the one it was in and takes its place among this one's,
    /// in the sunrise's order.
    mutating func moveStep(_ letter: Letter, in kind: String, to blockID: String) {
        guard var t = types?[kind] else { return }
        for g in TypeSchedule.Group.allCases {
            t[g] = t[g].map { st in
                var st = st
                if let ls = st.letters, ls.contains(letter.rawValue) {
                    let left = ls.filter { $0 != letter.rawValue }
                    st.letters = left.isEmpty ? nil : left
                }
                if st.id == blockID {
                    var ls = st.letters ?? []
                    let rank = Letter.allCases.firstIndex(of: letter) ?? 0
                    let at = ls.firstIndex { key in (Letter(rawValue: key).flatMap { Letter.allCases.firstIndex(of: $0) } ?? -1) > rank } ?? ls.endIndex
                    ls.insert(letter.rawValue, at: at)
                    st.letters = ls
                }
                return st
            }
        }
        types?[kind] = t
    }

    private mutating func changeBlock(_ kind: String, id: String, _ body: (inout Step) -> Void) {
        guard var t = types?[kind] else { return }
        for g in TypeSchedule.Group.allCases {
            var list = t[g]
            guard let i = list.firstIndex(where: { $0.id == id }) else { continue }
            body(&list[i])
            t[g] = list
        }
        types?[kind] = t
    }
}

extension TypeSchedule {
    /// Moves a block to where its hour for all days goes among the others of its group, so Hoy shows the day in
    /// order. The night's hours run from the evening past midnight.
    mutating func place(_ id: String) {
        for g in Group.allCases {
            var list = self[g]
            guard let i = list.firstIndex(where: { $0.id == id }) else { continue }
            let st = list.remove(at: i)
            let key = { (s: Step) -> Int? in
                guard let m = TimeText.minutes(s.time) else { return nil }
                return g == .night && m < 12 * 60 ? m + 24 * 60 : m
            }
            guard let mine = key(st) else {
                list.insert(st, at: i)
                self[g] = list
                return
            }
            let at = list.firstIndex { key($0).map { $0 > mine } ?? false } ?? list.endIndex
            list.insert(st, at: at)
            self[g] = list
            return
        }
    }
}
