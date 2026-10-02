import Foundation

/// What a pasted AI reply asks for: the changes that can be made, and the ones that can't, with why.
/// Anything the block doesn't name stays as it is.
struct AIProposal: Identifiable {
    enum Failure: Error {
        case noBlock

        var message: String { "No encontré cambios para Sunling en lo que copiaste" }
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

    /// For "Copiar para la IA".
    var problemsMessage: String {
        "La app no pudo aplicar estos cambios:\n" + problems.map { "- \($0)" }.joined(separator: "\n") +
            "\n\nCorrígelos y dame otra vez el bloque de cambios completo."
    }

    // MARK: Finding the block

    private static let topKeys: Set<String> = ["leeren", "afirmaciones", "visualizacion", "semana", "prepararte", "normal", "gym", "fechas"]

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

    /// Parsed, forgiving curly quotes and trailing commas; unwrapped from {"cambios": …}; nil if it isn't ours.
    private static func object(_ raw: String) -> [String: JSONValue]? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var value = try? JSONDecoder().decode(JSONValue.self, from: Data(s.utf8))
        if value == nil {
            s = s.replacingOccurrences(of: "“", with: "\"").replacingOccurrences(of: "”", with: "\"")
                .replacing(/,(\s*[}\]])/) { $0.1.description }
            value = try? JSONDecoder().decode(JSONValue.self, from: Data(s.utf8))
        }
        guard case .object(var o)? = value else { return nil }
        if o.count == 1, let (k, v) = o.first, ["cambios", "sunling", "savers", "cambiossavers"].contains(AIText.key(k)), case .object(let inner) = v { o = inner }
        return o.keys.contains { topKeys.contains(AIText.key($0)) } ? o : nil
    }

    // MARK: Reading it

    private mutating func add(_ edit: AIChange.Edit, _ title: String, _ context: String, _ detail: String, lines: [String] = []) {
        changes.append(AIChange(id: changes.count, edit: edit, title: title, context: context, detail: detail, lines: lines))
    }

    private mutating func problem(_ s: String) { problems.append(s) }

    private mutating func read(_ block: [String: JSONValue]) {
        // The week first: a date's hours depend on what its weekday will be.
        let week = block.filter { AIText.key($0.key) == "semana" }
        for (k, v) in week.sorted(by: { $0.key < $1.key }) + block.filter({ week[$0.key] == nil }).sorted(by: { $0.key < $1.key }) {
            switch AIText.key(k) {
            case "leeren": readReadApp(v)
            case "afirmaciones": readItems(v, current: r.settings.affirmations.filled, what: "Afirmaciones", noun: ("frase", "frases")) { .affirmations($0) }
            case "visualizacion": readVisualization(v)
            case "semana": readWeek(v)
            case "prepararte": readWindDown(v)
            case "normal": readKind(.normal, v)
            case "gym": readKind(.gym, v)
            case "fechas": readDates(v)
            default: problem("\(AIText.quoted(k)) no se puede cambiar desde la app.")
            }
        }
    }

    private static let readApps = [("libros", "Libros"), ("kindle", "Kindle"), ("papel", "Libro físico")]

    private mutating func readReadApp(_ v: JSONValue) {
        let k = AIText.key(v.text ?? "")
        let app = ["libros": "libros", "applebooks": "libros", "books": "libros", "kindle": "kindle",
                   "papel": "papel", "librofisico": "papel", "fisico": "papel"][k]
        guard let app else { return problem("\(AIText.quoted(v.text ?? "")) no es una forma de leer: usa libros, kindle o papel.") }
        guard app != r.settings.readApp else { return }
        let name = { (a: String) in Self.readApps.first { $0.0 == a }?.1 ?? a }
        add(.readApp(app), "Leer en", "", "\(name(r.settings.readApp)) → \(name(app))")
    }

    // MARK: Lists

    private mutating func readItems(_ v: JSONValue, current: [Item], what: String, noun: (String, String),
                                    _ edit: ([Item]) -> AIChange.Edit) {
        guard case .array(let list) = v else { return problem("\(what) tiene que ser la lista completa.") }
        var items: [Item] = []
        for x in list {
            switch x {
            case .string(let s): items.append(Item(text: s))
            case .object(let o):
                let label = (o.first { ["titulo", "title", "label"].contains(AIText.key($0.key)) }?.value.text) ?? ""
                let text = (o.first { ["texto", "text"].contains(AIText.key($0.key)) }?.value.text) ?? ""
                items.append(Item(label: label, text: text))
            default: return problem("En \(what.lowercased()), cada una tiene que ser un texto.")
            }
        }
        items = items.map { Item(label: $0.label.trimmingCharacters(in: .whitespacesAndNewlines), text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter(\.isFilled)
        guard !items.isEmpty else { return problem("\(what) no puede quedar vacía.") }
        guard items != current else { return }
        let count = { (n: Int) in "\(n) \(n == 1 ? noun.0 : noun.1)" }
        let detail = items.count == current.count ? count(items.count) : "\(count(current.count)) → \(count(items.count))"
        add(edit(items), what, "", detail, lines: Self.diff(current, items))
    }

    /// "2. «nueva» (antes «vieja»)", "4. Nueva: «…»", "Se quita: «…»", or "Cambia el orden".
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
            for k in 0..<paired { lines.append("\(new[k].0 + 1). \(Self.show(new[k].1)) (antes \(Self.show(gone[k])))") }
            for (p, x) in new.dropFirst(paired) { lines.append("\(p + 1). Nueva: \(Self.show(x))") }
            for x in gone.dropFirst(paired) { lines.append("Se quita: \(Self.show(x))") }
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
        if Set(a) == Set(b), a.count == b.count { return ["Cambia el orden"] }
        return lines
    }

    private static func show(_ i: Item) -> String { AIText.quoted(i.label.isEmpty ? i.text : "\(i.label): \(i.text)") }

    private mutating func readVisualization(_ v: JSONValue) {
        let current = r.settings.visualization
        if case .array = v {
            return readItems(v, current: current.items.filled, what: "Preguntas de visualización", noun: ("pregunta", "preguntas")) { .visualization($0) }
        }
        guard case .object(let o) = v else { return problem("Visualización tiene que tener \"preguntas\" y \"nota\".") }
        for (k, x) in o {
            switch AIText.key(k) {
            case "preguntas":
                readItems(x, current: current.items.filled, what: "Preguntas de visualización", noun: ("pregunta", "preguntas")) { .visualization($0) }
            case "nota":
                guard let n = x.text?.trimmingCharacters(in: .whitespacesAndNewlines) else { problem("La nota de visualización tiene que ser un texto."); continue }
                if n != current.note {
                    add(.visualizationNote(n), "Nota de visualización", "", "", lines: [current.note.isEmpty ? "Antes: (vacía)" : "Antes: \(AIText.quoted(current.note))",
                                                                                       n.isEmpty ? "Ahora: (vacía)" : "Ahora: \(AIText.quoted(n))"])
                }
            default: problem("En visualización, \(AIText.quoted(k)) no se puede cambiar.")
            }
        }
    }

    // MARK: The week

    private mutating func readWeek(_ v: JSONValue) {
        guard case .object(let o) = v else { return problem("\"semana\" tiene que decir qué es cada día.") }
        for (k, x) in o.sorted(by: { (AIText.weekday($0.key) ?? 9) < (AIText.weekday($1.key) ?? 9) }) {
            guard let w = AIText.weekday(k) else { problem("\(AIText.quoted(k)) no es un día de la semana."); continue }
            guard w != 6 else { problem("El sábado es Shabbat y no se cambia."); continue }
            guard let t = AIText.dayType(x) else { problem("\(AIText.quoted(x.text ?? "")) no es un tipo de día (\(Weekday.names[w])): usa normal, gym o descanso."); continue }
            let old = r.weekType(w)
            if t != old {
                add(.weekType(w, t), Weekday.names[w].capitalizedFirst, "Cada semana", "\(old.name) → \(t.name)")
                newWeek[w] = t
            }
        }
    }

    private mutating func readWindDown(_ v: JSONValue) {
        guard let m = AIText.minutes(v), Routine.windDownChoices.contains(m) else {
            return problem("Prepararte va de 15 a 90 minutos, de 5 en 5 (\(AIText.quoted(v.text ?? "")) no se puede).")
        }
        if m != r.windDown { add(.windDown(m), "Prepararte", "Antes de Dormido, todas las noches", "\(r.windDown) → \(m) min") }
    }

    // MARK: Normal and Gym

    private mutating func readKind(_ kind: DayType, _ v: JSONValue) {
        guard r.settings.schedule?.type(kind) != nil else { return problem("No hay horario de \(kind.name) en la app.") }
        guard case .object(let o) = v else { return problem("\"\(kind.rawValue)\" tiene que tener \"horas\" o \"minutos\".") }
        for (k, x) in o.sorted(by: { $0.key < $1.key }) {
            switch AIText.key(k) {
            case "horas": readHours(kind, x)
            case "horaspordia": readHoursPerDay(kind, x)
            case "minutos": readMinutes(kind, x)
            case "minutospordia": readMinutesPerDay(kind, x)
            default: problem("En \(kind.name), \(AIText.quoted(k)) no se puede cambiar.")
            }
        }
    }

    /// The block by its name, or a problem that lists the ones there are.
    private mutating func block(_ kind: DayType, _ name: String) -> (name: String, step: Step)? {
        if let b = r.aiBlock(kind, named: name) { return b }
        let names = r.aiBlocks(kind).map(\.name).joined(separator: ", ")
        problem("No existe el bloque \(AIText.quoted(name)) en \(kind.name). Los bloques son: \(names).")
        return nil
    }

    private mutating func readHours(_ kind: DayType, _ v: JSONValue) {
        guard case .object(let o) = v else { return problem("En \(kind.name), \"horas\" tiene que tener la hora de cada bloque.") }
        for (name, x) in o.sorted(by: { $0.key < $1.key }) {
            guard let b = block(kind, name), let id = b.step.id else { continue }
            if x == .null { problem("No se pueden quitar bloques (\(b.name) en \(kind.name))."); continue }
            guard let t = AIText.time(x) else { problem("\(AIText.quoted(x.text ?? "")) no es una hora (\(b.name) en \(kind.name))."); continue }
            let old = b.step.time ?? ""
            if !TimeText.same(t, old) { add(.stepTime(kind, stepID: id, weekday: nil, t), b.name, kind.name, "\(old.isEmpty ? "sin hora" : old) → \(t)") }
        }
    }

    private mutating func readHoursPerDay(_ kind: DayType, _ v: JSONValue) {
        guard case .object(let o) = v else { return problem("En \(kind.name), \"horasPorDia\" tiene que ir por bloque y por día.") }
        for (name, x) in o.sorted(by: { $0.key < $1.key }) {
            guard let b = block(kind, name), let id = b.step.id else { continue }
            guard case .object(let perDay) = x else { problem("En \(kind.name), las horas por día de \(b.name) van como {\"jueves\": \"5:40\"}."); continue }
            for (day, y) in perDay {
                guard let w = AIText.weekday(day), w != 6 else { problem("\(AIText.quoted(day)) no es un día que se pueda cambiar (\(b.name) en \(kind.name))."); continue }
                let all = b.step.time ?? ""
                let own = r.ownTime(b.step, weekday: w)
                let context = "\(kind.name) · solo \(Weekday.plural(w))"
                if y == .null {
                    if let own { add(.stepTime(kind, stepID: id, weekday: w, nil), b.name, context, "\(own) → como los demás días (\(all))") }
                    continue
                }
                guard let t = AIText.time(y) else { problem("\(AIText.quoted(y.text ?? "")) no es una hora (\(b.name), \(Weekday.names[w]))."); continue }
                let old = own ?? all
                if !TimeText.same(t, old) { add(.stepTime(kind, stepID: id, weekday: w, t), b.name, context, "\(old) → \(t)") }
            }
        }
    }

    /// Silencio or Lectura, or a problem saying why not.
    private mutating func editableLetter(_ name: String, _ where_: String) -> Letter? {
        guard let l = AIText.letter(name) else { problem("\(AIText.quoted(name)) no es un paso (\(where_))."); return nil }
        guard l.usualMinutes != nil else { problem("Los minutos de \(l.name) salen de su contenido y no se pueden cambiar."); return nil }
        return l
    }

    private mutating func minutesValue(_ v: JSONValue, _ l: Letter, _ where_: String) -> Int? {
        guard let n = AIText.minutes(v), Routine.minuteChoices.contains(n) else {
            problem("\(l.name): \(AIText.quoted(v.text ?? "")) minutos no se puede (\(where_)). Usa de 1 a 60, o 75, 90, 105 o 120.")
            return nil
        }
        return n
    }

    private mutating func readMinutes(_ kind: DayType, _ v: JSONValue) {
        guard case .object(let o) = v else { return problem("En \(kind.name), \"minutos\" va como {\"lee\": 15}.") }
        for (name, x) in o.sorted(by: { $0.key < $1.key }) {
            guard let l = editableLetter(name, kind.name), let n = minutesValue(x, l, kind.name) else { continue }
            let old = r.usualMinutes(kind, l, weekday: nil)
            if n != old { add(.minutes(kind, l, weekday: nil, n), l.name, kind.name, "\(old) → \(n) min") }
        }
    }

    private mutating func readMinutesPerDay(_ kind: DayType, _ v: JSONValue) {
        guard case .object(let o) = v else { return problem("En \(kind.name), \"minutosPorDia\" va como {\"lee\": {\"jueves\": 10}}.") }
        for (name, x) in o.sorted(by: { $0.key < $1.key }) {
            guard let l = editableLetter(name, kind.name) else { continue }
            guard case .object(let perDay) = x else { problem("En \(kind.name), los minutos por día de \(l.name) van como {\"jueves\": 10}."); continue }
            for (day, y) in perDay {
                guard let w = AIText.weekday(day), w != 6 else { problem("\(AIText.quoted(day)) no es un día que se pueda cambiar (\(l.name) en \(kind.name))."); continue }
                let all = r.usualMinutes(kind, l, weekday: nil)
                let own = r.ownMinutes(kind, l, weekday: w)
                let context = "\(kind.name) · solo \(Weekday.plural(w))"
                if y == .null {
                    if let own { add(.minutes(kind, l, weekday: w, nil), l.name, context, "\(own) → como los demás días (\(all) min)") }
                    continue
                }
                guard let n = minutesValue(y, l, "\(kind.name), \(Weekday.names[w])") else { continue }
                let old = own ?? all
                if n != old { add(.minutes(kind, l, weekday: w, n), l.name, context, "\(old) → \(n) min") }
            }
        }
    }

    // MARK: Dates

    private mutating func readDates(_ v: JSONValue) {
        guard case .object(let o) = v else { return problem("\"fechas\" va como {\"AAAA-MM-DD\": {…}}.") }
        let last = DayKey.adding(366, to: r.today)
        for (ds, x) in o.sorted(by: { $0.key < $1.key }) {
            guard DayKey.isValid(ds), DayKey.of(DayKey.date(ds)) == ds else { problem("\(AIText.quoted(ds)) no es una fecha (se escribe AAAA-MM-DD)."); continue }
            guard ds >= r.today else { problem("\(DayKey.long(ds)) ya pasó: solo se cambian fechas desde hoy."); continue }
            guard ds <= last else { problem("\(DayKey.long(ds)) está a más de un año: solo se cambian fechas hasta un año adelante."); continue }
            guard DayKey.weekday(ds) != 6 else { problem("\(DayKey.long(ds)) es sábado (Shabbat) y no se cambia."); continue }
            let title = DayKey.long(ds)
            if x == .null {
                if r.aiDateKeys().contains(ds) { add(.dateReset(ds), title, "Esa fecha", "Vuelve a ser como siempre") }
                continue
            }
            guard case .object(let d) = x else { problem("\(title): va como {\"tipo\": …, \"horas\": …, \"minutos\": …}."); continue }
            let was = r.dayType(ds)
            var type = r.days[ds]?.type == nil ? newWeek[DayKey.weekday(ds)] ?? was : was
            if let raw = d.first(where: { AIText.key($0.key) == "tipo" })?.value {
                if let t = AIText.dayType(raw) {
                    if t != was { add(.dateType(ds, t), title, "Esa fecha", "\(was.name) → \(t.name)") }
                    type = t
                } else {
                    problem("\(AIText.quoted(raw.text ?? "")) no es un tipo de día (\(title)): usa normal, gym o descanso.")
                }
            }
            let sameType = type == was
            for (k, y) in d.sorted(by: { $0.key < $1.key }) {
                let key = AIText.key(k)
                if (key == "horas" || key == "minutos") && !type.hasSavers {
                    problem("\(title) es \(type.name): no tiene horas ni minutos del amanecer.")
                    continue
                }
                switch key {
                case "tipo": break
                case "horas": readDateHours(ds, title, type, sameType, y)
                case "minutos": readDateMinutes(ds, title, type, sameType, y)
                default: problem("En \(title), \(AIText.quoted(k)) no se puede cambiar.")
                }
            }
        }
    }

    private mutating func readDateHours(_ ds: String, _ title: String, _ type: DayType, _ sameType: Bool, _ v: JSONValue) {
        guard case .object(let o) = v else { return problem("\(title): \"horas\" va como {\"Amanecer\": \"7:00\"}.") }
        let kind: DayType = type == .gym ? .gym : .normal
        for (name, y) in o.sorted(by: { $0.key < $1.key }) {
            guard let b = block(kind, name), let id = b.step.id else { continue }
            let usual = r.usualTime(b.step, weekday: DayKey.weekday(ds))
            let now = sameType ? r.time(of: b.step, on: ds) : usual
            let context = "Solo esa fecha · \(title)"
            if y == .null {
                if !TimeText.same(now, usual) { add(.dateTime(ds, stepID: id, nil), b.name, context, "\(now) → como siempre (\(usual))") }
                continue
            }
            guard let t = AIText.time(y) else { problem("\(AIText.quoted(y.text ?? "")) no es una hora (\(b.name), \(title))."); continue }
            if !TimeText.same(t, now) { add(.dateTime(ds, stepID: id, t), b.name, context, "\(now) → \(t)") }
        }
    }

    private mutating func readDateMinutes(_ ds: String, _ title: String, _ type: DayType, _ sameType: Bool, _ v: JSONValue) {
        guard case .object(let o) = v else { return problem("\(title): \"minutos\" va como {\"lee\": 20}.") }
        let kind: DayType = type == .gym ? .gym : .normal
        for (name, y) in o.sorted(by: { $0.key < $1.key }) {
            guard let l = editableLetter(name, title) else { continue }
            let usual = r.usualMinutes(kind, l, weekday: DayKey.weekday(ds))
            let now = sameType ? r.minutesOn(kind, l, on: ds) : usual
            let context = "Solo esa fecha · \(title)"
            if y == .null {
                if now != usual { add(.dateMinutes(ds, l, nil), l.name, context, "\(now) → como siempre (\(usual) min)") }
                continue
            }
            guard let n = minutesValue(y, l, title) else { continue }
            if n != now { add(.dateMinutes(ds, l, n), l.name, context, "\(now) → \(n) min") }
        }
    }
}
