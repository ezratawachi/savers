import Foundation

/// What a pasted AI reply asks for: the changes that can be made, and the ones that can't, with why.
/// Anything the block doesn't name stays as it is.
struct AIProposal: Identifiable {
    enum Failure: Error {
        case noBlock

        var message: String { String(localized: "I didn't find any changes for Sunling in what you copied") }
    }

    let id = UUID()
    private(set) var changes: [AIChange] = []
    private(set) var problems: [String] = []
    private let r: Routine
    /// The weekdays the same block changes, so its dates are read as they'll be.
    private var newWeek: [Int: DayType] = [:]

    init(text: String, routine: Routine) throws(Failure) {
        guard let block = Self.block(in: text) else { throw .noBlock }
        r = routine
        read(block)
        changes.sort { ($0.order, $0.id) < ($1.order, $1.id) }
    }

    /// For "Copy for the AI".
    var problemsMessage: String {
        String(localized: "The app couldn't apply these changes:") + "\n" + problems.map { "- \($0)" }.joined(separator: "\n") +
            "\n\n" + String(localized: "Fix them and give me the whole change block again.")
    }

    // MARK: Finding the block

    /// The configuration's words in either language, as `AIText.key` leaves them.
    private static let topKeys: Set<String> = ["leeren", "readon", "readin", "afirmaciones", "affirmations", "visualizacion", "visualization",
                                               "semana", "week", "prepararte", "winddown", "normal", "gym", "fechas", "dates"]

    /// The ```sunling block (```savers before), or else the last JSON object in the text that looks like one.
    static func block(in text: String) -> [String: JSONValue]? {
        if let m = text.firstMatch(of: /```[ \t]*(?:sunling|savers)[ \t]*\n([\s\S]*?)```/), let o = object(String(m.1)) { return o }
        return objects(in: text).reversed().lazy.compactMap(object).first
    }

    /// Every outermost {…} in the text, minding quotes.
    private static func objects(in text: String) -> [String] {
        var out: [String] = []
        var depth = 0
        var start: String.Index?
        var inString = false
        var escaped = false
        for i in text.indices {
            let c = text[i]
            if inString {
                if escaped { escaped = false } else if c == "\\" { escaped = true } else if c == "\"" || c == "”" { inString = false }
                continue
            }
            switch c {
            case "\"", "“": inString = depth > 0
            case "{":
                if depth == 0 { start = i }
                depth += 1
            case "}" where depth > 0:
                depth -= 1
                if depth == 0, let s = start { out.append(String(text[s...i])) }
            default: break
            }
        }
        return out
    }

    /// Parsed, forgiving curly quotes and trailing commas; unwrapped from {"changes": …}; nil if it isn't ours.
    private static func object(_ raw: String) -> [String: JSONValue]? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var value = try? JSONDecoder().decode(JSONValue.self, from: Data(s.utf8))
        if value == nil {
            s = s.replacingOccurrences(of: "“", with: "\"").replacingOccurrences(of: "”", with: "\"")
                .replacing(/,(\s*[}\]])/) { $0.1.description }
            value = try? JSONDecoder().decode(JSONValue.self, from: Data(s.utf8))
        }
        guard case .object(var o)? = value else { return nil }
        if o.count == 1, let (k, v) = o.first, ["cambios", "changes", "sunling", "savers", "cambiossavers"].contains(AIText.key(k)), case .object(let inner) = v { o = inner }
        return o.keys.contains { topKeys.contains(AIText.key($0)) } ? o : nil
    }

    // MARK: Reading it

    private mutating func add(_ edit: AIChange.Edit, _ title: String, _ context: String, _ detail: String, lines: [String] = []) {
        changes.append(AIChange(id: changes.count, edit: edit, title: title, context: context, detail: detail, lines: lines))
    }

    private mutating func problem(_ s: String) { problems.append(s) }

    private mutating func read(_ block: [String: JSONValue]) {
        // The week first: a date's hours depend on what its weekday will be.
        let week = block.filter { ["semana", "week"].contains(AIText.key($0.key)) }
        for (k, v) in week.sorted(by: { $0.key < $1.key }) + block.filter({ week[$0.key] == nil }).sorted(by: { $0.key < $1.key }) {
            switch AIText.key(k) {
            case "leeren", "readon", "readin": readReadApp(v)
            case "afirmaciones", "affirmations": readItems(v, current: r.settings.affirmations.filled, .affirmations) { .affirmations($0) }
            case "visualizacion", "visualization": readVisualization(v)
            case "semana", "week": readWeek(v)
            case "prepararte", "winddown": readWindDown(v)
            case "normal": readKind(.normal, v)
            case "gym": readKind(.gym, v)
            case "fechas", "dates": readDates(v)
            default: problem(String(localized: "\(AIText.quoted(k)) can't be changed from the app."))
            }
        }
    }

    private mutating func readReadApp(_ v: JSONValue) {
        let k = AIText.key(v.text ?? "")
        let app = ["libros": "libros", "applebooks": "libros", "books": "libros", "kindle": "kindle",
                   "papel": "papel", "librofisico": "papel", "fisico": "papel", "paper": "papel", "printbook": "papel", "physicalbook": "papel"][k]
        guard let app else { return problem(String(localized: "\(AIText.quoted(v.text ?? "")) isn't a way to read: use books, kindle or paper.")) }
        guard app != r.settings.readApp else { return }
        add(.readApp(app), String(localized: "Read on"), "", "\(ReadApp(r.settings.readApp).name) → \(ReadApp(app).name)")
    }

    // MARK: Lists

    private mutating func readItems(_ v: JSONValue, current: [Item], _ kind: ItemsKind, _ edit: ([Item]) -> AIChange.Edit) {
        guard case .array(let list) = v else { return problem(kind.aiWholeList) }
        var items: [Item] = []
        for x in list {
            switch x {
            case .string(let s): items.append(Item(text: s))
            case .object(let o):
                let label = (o.first { ["titulo", "title", "label"].contains(AIText.key($0.key)) }?.value.text) ?? ""
                let text = (o.first { ["texto", "text"].contains(AIText.key($0.key)) }?.value.text) ?? ""
                items.append(Item(label: label, text: text))
            default: return problem(kind.aiEachText)
            }
        }
        items = items.map { Item(label: $0.label.trimmingCharacters(in: .whitespacesAndNewlines), text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter(\.isFilled)
        guard !items.isEmpty else { return problem(kind.aiNotEmpty) }
        guard items != current else { return }
        let detail = items.count == current.count ? kind.count(items.count) : "\(kind.count(current.count)) → \(kind.count(items.count))"
        add(edit(items), kind.aiTitle, "", detail, lines: Self.diff(current, items))
    }

    /// "2. “new” (was “old”)", "4. New: “…”", "Removed: “…”", or "The order changes".
    static func diff(_ a: [Item], _ b: [Item]) -> [String] {
        let n = a.count, m = b.count
        var lcs = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                lcs[i][j] = a[i] == b[j] ? lcs[i + 1][j + 1] + 1 : max(lcs[i + 1][j], lcs[i][j + 1])
            }
        }
        var lines: [String] = []
        var i = 0, j = 0
        var gone: [Item] = []
        var new: [(Int, Item)] = []
        func flush() {
            let paired = min(gone.count, new.count)
            for k in 0..<paired { lines.append(String(localized: "\(new[k].0 + 1). \(Self.show(new[k].1)) (was \(Self.show(gone[k])))")) }
            for (p, x) in new.dropFirst(paired) { lines.append(String(localized: "\(p + 1). New: \(Self.show(x))")) }
            for x in gone.dropFirst(paired) { lines.append(String(localized: "Removed: \(Self.show(x))")) }
            gone = []
            new = []
        }
        while i < n || j < m {
            if i < n, j < m, a[i] == b[j] {
                flush()
                i += 1
                j += 1
            } else if j < m, i == n || lcs[i][j + 1] >= lcs[i + 1][j] {
                new.append((j, b[j]))
                j += 1
            } else {
                gone.append(a[i])
                i += 1
            }
        }
        flush()
        if Set(a) == Set(b), a.count == b.count { return [String(localized: "The order changes")] }
        return lines
    }

    private static func show(_ i: Item) -> String { AIText.quoted(i.label.isEmpty ? i.text : "\(i.label): \(i.text)") }

    private mutating func readVisualization(_ v: JSONValue) {
        let current = r.settings.visualization
        if case .array = v {
            return readItems(v, current: current.items.filled, .visualization) { .visualization($0) }
        }
        guard case .object(let o) = v else {
            return problem(String(localized: "\(AIWord.visualization) has to have \"\(AIWord.questions)\" and \"\(AIWord.note)\"."))
        }
        for (k, x) in o {
            switch AIText.key(k) {
            case "preguntas", "questions":
                readItems(x, current: current.items.filled, .visualization) { .visualization($0) }
            case "nota", "note":
                guard let n = x.text?.trimmingCharacters(in: .whitespacesAndNewlines) else { problem(String(localized: "The Imagine note has to be a text.")); continue }
                if n != current.note {
                    add(.visualizationNote(n), String(localized: "Imagine note"), "", "", lines: [
                        current.note.isEmpty ? String(localized: "Before: (empty)") : String(localized: "Before: \(AIText.quoted(current.note))"),
                        n.isEmpty ? String(localized: "Now: (empty)") : String(localized: "Now: \(AIText.quoted(n))"),
                    ])
                }
            default: problem(String(localized: "In Imagine, \(AIText.quoted(k)) can't be changed."))
            }
        }
    }

    // MARK: The week

    private mutating func readWeek(_ v: JSONValue) {
        guard case .object(let o) = v else { return problem(String(localized: "\"\(AIWord.week)\" has to say what each day is.")) }
        for (k, x) in o.sorted(by: { (AIText.weekday($0.key) ?? 9) < (AIText.weekday($1.key) ?? 9) }) {
            guard let w = AIText.weekday(k) else { problem(String(localized: "\(AIText.quoted(k)) isn't a weekday.")); continue }
            guard w != 6 else { problem(String(localized: "Saturday is Shabbat and doesn't change.")); continue }
            guard let t = AIText.dayType(x) else { problem(String(localized: "\(AIText.quoted(x.text ?? "")) isn't a kind of day (\(Weekday.names[w])): use normal, gym or rest.")); continue }
            let old = r.weekType(w)
            if t != old {
                add(.weekType(w, t), Weekday.names[w].capitalizedFirst, String(localized: "Every week"), "\(old.name) → \(t.name)")
                newWeek[w] = t
            }
        }
    }

    private mutating func readWindDown(_ v: JSONValue) {
        guard let m = AIText.minutes(v), Routine.windDownChoices.contains(m) else {
            return problem(String(localized: "Wind down goes from 15 to 90 minutes, in steps of 5 (\(AIText.quoted(v.text ?? "")) isn't possible)."))
        }
        if m != r.windDown {
            add(.windDown(m), String(localized: "Wind down"), String(localized: "Before bedtime, every night"), String(localized: "\(r.windDown) → \(m) min"))
        }
    }

    // MARK: Normal and Gym

    private mutating func readKind(_ kind: DayType, _ v: JSONValue) {
        guard r.settings.schedule?.type(kind) != nil else { return problem(String(localized: "There's no \(kind.name) schedule in the app.")) }
        guard case .object(let o) = v else {
            return problem(String(localized: "\"\(kind.rawValue)\" has to have \"\(AIWord.hours)\" or \"\(AIWord.minutes)\"."))
        }
        for (k, x) in o.sorted(by: { $0.key < $1.key }) {
            switch AIText.key(k) {
            case "horas", "hours": readHours(kind, x)
            case "horaspordia", "hoursbyday", "hoursperday": readHoursPerDay(kind, x)
            case "minutos", "minutes": readMinutes(kind, x)
            case "minutospordia", "minutesbyday", "minutesperday": readMinutesPerDay(kind, x)
            default: problem(String(localized: "In \(kind.name), \(AIText.quoted(k)) can't be changed."))
            }
        }
    }

    /// The block by its name, or a problem that lists the ones there are.
    private mutating func block(_ kind: DayType, _ name: String) -> (name: String, step: Step)? {
        if let b = r.aiBlock(kind, named: name) { return b }
        let names = r.aiBlocks(kind).map(\.name).joined(separator: ", ")
        problem(String(localized: "There's no block \(AIText.quoted(name)) in \(kind.name). The blocks are: \(names)."))
        return nil
    }

    private mutating func readHours(_ kind: DayType, _ v: JSONValue) {
        guard case .object(let o) = v else { return problem(String(localized: "In \(kind.name), \"\(AIWord.hours)\" has to have each block's time.")) }
        for (name, x) in o.sorted(by: { $0.key < $1.key }) {
            guard let b = block(kind, name), let id = b.step.id else { continue }
            if x == .null { problem(String(localized: "Blocks can't be removed (\(b.name) in \(kind.name)).")); continue }
            guard let t = AIText.time(x) else { problem(String(localized: "\(AIText.quoted(x.text ?? "")) isn't a time (\(b.name) in \(kind.name)).")); continue }
            let old = b.step.time ?? ""
            if !TimeText.same(t, old) { add(.stepTime(kind, stepID: id, weekday: nil, t), b.name, kind.name, "\(old.isEmpty ? String(localized: "no time") : old) → \(t)") }
        }
    }

    private mutating func readHoursPerDay(_ kind: DayType, _ v: JSONValue) {
        guard case .object(let o) = v else { return problem(String(localized: "In \(kind.name), \"\(AIWord.hoursByDay)\" has to go by block and by day.")) }
        for (name, x) in o.sorted(by: { $0.key < $1.key }) {
            guard let b = block(kind, name), let id = b.step.id else { continue }
            guard case .object(let perDay) = x else {
                problem(String(localized: "In \(kind.name), \(b.name)'s hours by day go like {\"\(AIWord.weekday(4))\": \"5:40\"}."))
                continue
            }
            for (day, y) in perDay {
                guard let w = AIText.weekday(day), w != 6 else {
                    problem(String(localized: "\(AIText.quoted(day)) isn't a day that can be changed (\(b.name) in \(kind.name))."))
                    continue
                }
                let all = b.step.time ?? ""
                let own = r.ownTime(b.step, weekday: w)
                let context = String(localized: "\(kind.name) · \(Weekday.plural(w)) only")
                if y == .null {
                    if let own { add(.stepTime(kind, stepID: id, weekday: w, nil), b.name, context, String(localized: "\(own) → like the other days (\(all))")) }
                    continue
                }
                guard let t = AIText.time(y) else { problem(String(localized: "\(AIText.quoted(y.text ?? "")) isn't a time (\(b.name), \(Weekday.names[w])).")); continue }
                let old = own ?? all
                if !TimeText.same(t, old) { add(.stepTime(kind, stepID: id, weekday: w, t), b.name, context, "\(old) → \(t)") }
            }
        }
    }

    /// Breathe or Read, or a problem saying why not.
    private mutating func editableLetter(_ name: String, _ where_: String) -> Letter? {
        guard let l = AIText.letter(name) else { problem(String(localized: "\(AIText.quoted(name)) isn't a step (\(where_)).")); return nil }
        guard l.usualMinutes != nil else { problem(String(localized: "\(l.name)'s minutes come from its content and can't be changed.")); return nil }
        return l
    }

    private mutating func minutesValue(_ v: JSONValue, _ l: Letter, _ where_: String) -> Int? {
        guard let n = AIText.minutes(v), Routine.minuteChoices.contains(n) else {
            problem(String(localized: "\(l.name): \(AIText.quoted(v.text ?? "")) minutes isn't possible (\(where_)). Use 1 to 60, or 75, 90, 105 or 120."))
            return nil
        }
        return n
    }

    private mutating func readMinutes(_ kind: DayType, _ v: JSONValue) {
        guard case .object(let o) = v else {
            return problem(String(localized: "In \(kind.name), \"\(AIWord.minutes)\" goes like {\"\(Letter.lectura.aiKey)\": 15}."))
        }
        for (name, x) in o.sorted(by: { $0.key < $1.key }) {
            guard let l = editableLetter(name, kind.name), let n = minutesValue(x, l, kind.name) else { continue }
            let old = r.usualMinutes(kind, l, weekday: nil)
            if n != old { add(.minutes(kind, l, weekday: nil, n), l.name, kind.name, String(localized: "\(old) → \(n) min")) }
        }
    }

    private mutating func readMinutesPerDay(_ kind: DayType, _ v: JSONValue) {
        guard case .object(let o) = v else {
            return problem(String(localized: "In \(kind.name), \"\(AIWord.minutesByDay)\" goes like {\"\(Letter.lectura.aiKey)\": {\"\(AIWord.weekday(4))\": 10}}."))
        }
        for (name, x) in o.sorted(by: { $0.key < $1.key }) {
            guard let l = editableLetter(name, kind.name) else { continue }
            guard case .object(let perDay) = x else {
                problem(String(localized: "In \(kind.name), \(l.name)'s minutes by day go like {\"\(AIWord.weekday(4))\": 10}."))
                continue
            }
            for (day, y) in perDay {
                guard let w = AIText.weekday(day), w != 6 else {
                    problem(String(localized: "\(AIText.quoted(day)) isn't a day that can be changed (\(l.name) in \(kind.name))."))
                    continue
                }
                let all = r.usualMinutes(kind, l, weekday: nil)
                let own = r.ownMinutes(kind, l, weekday: w)
                let context = String(localized: "\(kind.name) · \(Weekday.plural(w)) only")
                if y == .null {
                    if let own { add(.minutes(kind, l, weekday: w, nil), l.name, context, String(localized: "\(own) → like the other days (\(all) min)")) }
                    continue
                }
                guard let n = minutesValue(y, l, "\(kind.name), \(Weekday.names[w])") else { continue }
                let old = own ?? all
                if n != old { add(.minutes(kind, l, weekday: w, n), l.name, context, String(localized: "\(old) → \(n) min")) }
            }
        }
    }

    // MARK: Dates

    private mutating func readDates(_ v: JSONValue) {
        guard case .object(let o) = v else { return problem(String(localized: "\"\(AIWord.dates)\" goes like {\"YYYY-MM-DD\": {…}}.")) }
        let last = DayKey.adding(366, to: r.today)
        for (ds, x) in o.sorted(by: { $0.key < $1.key }) {
            guard DayKey.isValid(ds), DayKey.of(DayKey.date(ds)) == ds else { problem(String(localized: "\(AIText.quoted(ds)) isn't a date (it's written YYYY-MM-DD).")); continue }
            guard ds >= r.today else { problem(String(localized: "\(DayKey.long(ds)) has passed: only dates from today on can be changed.")); continue }
            guard ds <= last else { problem(String(localized: "\(DayKey.long(ds)) is more than a year away: only dates up to a year ahead can be changed.")); continue }
            guard DayKey.weekday(ds) != 6 else { problem(String(localized: "\(DayKey.long(ds)) is a Saturday (Shabbat) and doesn't change.")); continue }
            let title = DayKey.long(ds)
            if x == .null {
                if r.aiDateKeys().contains(ds) { add(.dateReset(ds), title, String(localized: "That date"), String(localized: "Goes back to the usual")) }
                continue
            }
            guard case .object(let d) = x else {
                problem(String(localized: "\(title): it goes like {\"\(AIWord.type)\": …, \"\(AIWord.hours)\": …, \"\(AIWord.minutes)\": …}."))
                continue
            }
            let was = r.dayType(ds)
            var type = r.days[ds]?.type == nil ? newWeek[DayKey.weekday(ds)] ?? was : was
            if let raw = d.first(where: { ["tipo", "type"].contains(AIText.key($0.key)) })?.value {
                if let t = AIText.dayType(raw) {
                    if t != was { add(.dateType(ds, t), title, String(localized: "That date"), "\(was.name) → \(t.name)") }
                    type = t
                } else {
                    problem(String(localized: "\(AIText.quoted(raw.text ?? "")) isn't a kind of day (\(title)): use normal, gym or rest."))
                }
            }
            let sameType = type == was
            for (k, y) in d.sorted(by: { $0.key < $1.key }) {
                let key = AIText.key(k)
                if ["horas", "hours", "minutos", "minutes"].contains(key) && !type.hasSavers {
                    problem(String(localized: "\(title) is \(type.name): it has no sunrise hours or minutes."))
                    continue
                }
                switch key {
                case "tipo", "type": break
                case "horas", "hours": readDateHours(ds, title, type, sameType, y)
                case "minutos", "minutes": readDateMinutes(ds, title, type, sameType, y)
                default: problem(String(localized: "In \(title), \(AIText.quoted(k)) can't be changed."))
                }
            }
        }
    }

    private mutating func readDateHours(_ ds: String, _ title: String, _ type: DayType, _ sameType: Bool, _ v: JSONValue) {
        guard case .object(let o) = v else {
            return problem(String(localized: "\(title): \"\(AIWord.hours)\" goes like {\"\(String(localized: "Sunrise"))\": \"7:00\"}."))
        }
        let kind: DayType = type == .gym ? .gym : .normal
        for (name, y) in o.sorted(by: { $0.key < $1.key }) {
            guard let b = block(kind, name), let id = b.step.id else { continue }
            let usual = r.usualTime(b.step, weekday: DayKey.weekday(ds))
            let now = sameType ? r.time(of: b.step, on: ds) : usual
            let context = String(localized: "That date only · \(title)")
            if y == .null {
                if !TimeText.same(now, usual) { add(.dateTime(ds, stepID: id, nil), b.name, context, String(localized: "\(now) → as usual (\(usual))")) }
                continue
            }
            guard let t = AIText.time(y) else { problem(String(localized: "\(AIText.quoted(y.text ?? "")) isn't a time (\(b.name), \(title)).")); continue }
            if !TimeText.same(t, now) { add(.dateTime(ds, stepID: id, t), b.name, context, "\(now) → \(t)") }
        }
    }

    private mutating func readDateMinutes(_ ds: String, _ title: String, _ type: DayType, _ sameType: Bool, _ v: JSONValue) {
        guard case .object(let o) = v else {
            return problem(String(localized: "\(title): \"\(AIWord.minutes)\" goes like {\"\(Letter.lectura.aiKey)\": 20}."))
        }
        let kind: DayType = type == .gym ? .gym : .normal
        for (name, y) in o.sorted(by: { $0.key < $1.key }) {
            guard let l = editableLetter(name, title) else { continue }
            let usual = r.usualMinutes(kind, l, weekday: DayKey.weekday(ds))
            let now = sameType ? r.minutesOn(kind, l, on: ds) : usual
            let context = String(localized: "That date only · \(title)")
            if y == .null {
                if now != usual { add(.dateMinutes(ds, l, nil), l.name, context, String(localized: "\(now) → as usual (\(usual) min)")) }
                continue
            }
            guard let n = minutesValue(y, l, title) else { continue }
            if n != now { add(.dateMinutes(ds, l, n), l.name, context, String(localized: "\(now) → \(n) min")) }
        }
    }
}

/// How the changes and the problems name each list.
private extension ItemsKind {
    var aiTitle: String {
        switch self {
        case .affirmations: String(localized: "Affirmations")
        case .visualization: String(localized: "Imagine questions")
        }
    }

    var aiWholeList: String {
        switch self {
        case .affirmations: String(localized: "Affirmations have to be the whole list.")
        case .visualization: String(localized: "Imagine questions have to be the whole list.")
        }
    }

    var aiEachText: String {
        switch self {
        case .affirmations: String(localized: "In affirmations, each one has to be a text.")
        case .visualization: String(localized: "In Imagine questions, each one has to be a text.")
        }
    }

    var aiNotEmpty: String {
        switch self {
        case .affirmations: String(localized: "Affirmations can't be left empty.")
        case .visualization: String(localized: "Imagine questions can't be left empty.")
        }
    }

    /// "3 phrases", "1 question"
    func count(_ n: Int) -> String {
        switch self {
        case .affirmations: String(localized: "\(n) phrases")
        case .visualization: String(localized: "\(n) questions")
        }
    }
}
