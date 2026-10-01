import Foundation

/// What "Mandar a la IA" sends: the instructions, the notes, the question, each day as it is, the last
/// weeks' marks and the configuration the AI can change. Never what was written in Escritura.
enum AIPacket {
    static let weeks = 8

    static func text(_ r: Routine, question: String) -> String {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = r.settings.aiNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = r.settings.name.trimmingCharacters(in: .whitespaces)
        var parts: [String] = []
        parts.append("# Mi rutina SAVERS\n\n" + (name.isEmpty ? "" : "Me llamo \(name). ") +
            "Hoy es \(DayKey.long(r.today).lowercased()) (\(r.today)). Te paso todo lo de mi app de SAVERS para que me ayudes.")
        parts.append("## Lo que quiero\n\n" + (q.isEmpty ? "Todavía no lo sé. Pregúntame de qué quiero hablar." : q))
        parts.append("## Mis notas (lo que la app no sabe)\n\n" + (notes.isEmpty ? "Sin notas." : notes))
        parts.append(howToWork)
        parts.append(howItWorks)
        parts.append("## Así es cada día (lo calcula la app, solo para leer)\n\n" + r.aiWeek())
        let dates = r.aiDates()
        if !dates.isEmpty { parts.append("## Fechas con cambios (solo para leer)\n\n" + dates) }
        parts.append("## Cómo me ha ido (últimas \(weeks) semanas, solo para leer)\n\n" + r.aiRecord(weeks: weeks))
        parts.append("## Mi configuración (esto es lo que se puede cambiar)\n\n```json\n" + r.aiConfig().rendered() + "\n```")
        parts.append(changeBlock(r))
        return parts.joined(separator: "\n\n") + "\n"
    }

    private static let howToWork = """
    ## Cómo trabajar conmigo

    - Primero conversa: entiende lo que te pido, pregúntame lo que no sepas y propón ideas. No siempre quiero cambiar algo; a veces quiero pensar o discutir.
    - Respeta mis notas: lo que dicen que no se mueve, no se mueve.
    - Dame el bloque de cambios solo cuando yo acepte una propuesta o te pida los cambios. Antes no.
    - Antes de proponer una hora, revisa que las letras del bloque terminen antes del bloque siguiente.
    """

    private static let howItWorks = """
    ## Cómo funciona la app

    - SAVERS son seis letras: Silencio, Afirmaciones, Visualización, Ejercicio, Lectura y Escritura.
    - Cada día de la semana es Normal, Gym o Sin SAVERS. El sábado es Shabbat y no se cambia.
    - Normal y Gym tienen su propio horario de bloques con hora (por ejemplo Te paras, SAVERS, Baño, Dormido). Algunos bloques tienen letras dentro, en orden.
    - La hora de cada letra es la hora de su bloque más los minutos de las letras que van antes. Para mover una letra, se mueve su bloque o se cambian minutos.
    - Solo Silencio y Lectura tienen minutos que se pueden cambiar: de 1 a 60, o 75, 90, 105 o 120. Los de las otras letras salen de su contenido (Afirmaciones unos 25 segundos por frase, Visualización 1 minuto por pregunta, Escritura 2, Ejercicio 8 o lo que dura el gym).
    - "Dormido" está en "La noche anterior": es la hora de dormir de la noche antes de ese día. "Prepararte" son los minutos antes de Dormido en que me llega el aviso para prepararme: de 15 a 90, de 5 en 5, el mismo todas las noches.
    - Una hora o unos minutos pueden ser distintos un día de la semana ("horasPorDia", "minutosPorDia") o una fecha ("fechas", desde hoy hasta un año adelante).
    - No se pueden agregar, quitar ni renombrar bloques, ni mover letras de un bloque a otro. Si eso me convendría, dímelo en la conversación, no en el bloque de cambios.
    """

    private static func changeBlock(_ r: Routine) -> String {
        let block = r.aiBlocks(.normal).first { !$0.step.letterKeys.isEmpty }?.name ?? "SAVERS"
        return """
        ## El bloque de cambios

        Cuando yo te lo pida, al final de tu respuesta pon un bloque de código marcado `savers` con un JSON que tenga **solo lo que cambia**, con la misma forma que mi configuración. Lo que no pongas se queda igual.

        - Las horas de la mañana se escriben "5:20"; las de la tarde y la noche, con pm: "8:50 pm".
        - Para que la hora o los minutos de un día de la semana o de una fecha vuelvan a ser como siempre, ponles null. Para quitar todos los cambios de una fecha: "AAAA-MM-DD": null.
        - Las afirmaciones y las preguntas de visualización van completas y en su orden final, aunque cambie una sola.
        - Usa los nombres de los bloques tal como están en mi configuración.

        Ejemplo de la forma (no es una propuesta):

        ```savers
        {
          "normal": {"horas": {"\(block)": "5:45"}, "minutos": {"lectura": 15}},
          "semana": {"jueves": "gym"},
          "fechas": {"AAAA-MM-DD": {"tipo": "sin savers"}}
        }
        ```

        Yo copio tu respuesta y la pego en la app, que me muestra cada cambio antes de aplicarlo.
        """
    }
}

extension DayType {
    /// How the configuration writes it: "normal", "gym", "sin savers".
    var aiName: String {
        switch self {
        case .normal: "normal"
        case .gym: "gym"
        case .off: "sin savers"
        case .shabbat: "shabbat"
        }
    }
}

extension Routine {
    // MARK: The configuration

    func aiConfig() -> OrderedJSON {
        var top: [(String, OrderedJSON)] = [
            ("nombre", .string(settings.name)),
            ("leerEn", .string(settings.readApp)),
            ("afirmaciones", .array(settings.affirmations.filled.map(Self.aiItem))),
            ("visualizacion", .object([
                ("preguntas", .array(settings.visualization.items.filled.map(Self.aiItem))),
                ("nota", .string(settings.visualization.note)),
            ])),
            ("semana", .object((0...5).map { (Weekday.names[$0], .string(weekType($0).aiName)) })),
            ("prepararte", .number(windDown)),
        ]
        for kind in [DayType.normal, .gym] where settings.schedule?.type(kind) != nil {
            top.append((kind.rawValue, aiKind(kind)))
        }
        top.append(("fechas", .object(aiDateKeys().map { ($0, aiDate($0)) })))
        return .object(top)
    }

    private static func aiItem(_ i: Item) -> OrderedJSON {
        i.label.isEmpty ? .string(i.text) : .object([("titulo", .string(i.label)), ("texto", .string(i.text))])
    }

    private func aiKind(_ kind: DayType) -> OrderedJSON {
        let blocks = aiBlocks(kind)
        var out: [(String, OrderedJSON)] = [("horas", .object(blocks.map { ($0.name, .string($0.step.time ?? "")) }))]
        let perDay: [(String, OrderedJSON)] = blocks.compactMap { b in
            let own = (0...5).compactMap { w in ownTime(b.step, weekday: w).map { (Weekday.names[w], OrderedJSON.string($0)) } }
            return own.isEmpty ? nil : (b.name, .object(own))
        }
        if !perDay.isEmpty { out.append(("horasPorDia", .object(perDay))) }
        let letters = [Letter.silencio, .lectura]
        out.append(("minutos", .object(letters.map { ($0.rawValue, .number(usualMinutes(kind, $0, weekday: nil))) })))
        let minsPerDay: [(String, OrderedJSON)] = letters.compactMap { l in
            let own = (0...5).compactMap { w in ownMinutes(kind, l, weekday: w).map { (Weekday.names[w], OrderedJSON.number($0)) } }
            return own.isEmpty ? nil : (l.rawValue, .object(own))
        }
        if !minsPerDay.isEmpty { out.append(("minutosPorDia", .object(minsPerDay))) }
        return .object(out)
    }

    /// Dates from today on with a kind, hours or minutes of their own.
    func aiDateKeys() -> [String] {
        days.keys.filter { ds in
            guard ds >= today, let d = days[ds] else { return false }
            return d.type != nil || dateEdited(ds)
        }.sorted()
    }

    private func aiDate(_ ds: String) -> OrderedJSON {
        let d = day(ds)
        var out: [(String, OrderedJSON)] = []
        if d.type != nil { out.append(("tipo", .string(dayType(ds).aiName))) }
        if isScheduled(ds) {
            let kind = scheduleKind(ds)
            let hours: [(String, OrderedJSON)] = aiBlocks(kind).compactMap { b in
                guard let id = b.step.id, let t = d.times?[id], !t.isEmpty else { return nil }
                return (b.name, .string(t))
            }
            if !hours.isEmpty { out.append(("horas", .object(hours))) }
            let mins: [(String, OrderedJSON)] = [Letter.silencio, .lectura].compactMap { l in
                Self.valid(d.mins?[l.rawValue]).map { (l.rawValue, .number($0)) }
            }
            if !mins.isEmpty { out.append(("minutos", .object(mins))) }
        }
        return .object(out)
    }

    // MARK: Each day as text

    /// The week, weekdays that look the same together: "Lunes, martes y jueves (Normal)" and their hours.
    func aiWeek() -> String {
        var order: [String] = []
        var who: [String: [Int]] = [:]
        for w in 0...6 {
            let type = weekType(w)
            let body = type.hasSavers
                ? aiTimeline(type, time: { usualTime($0, weekday: w) }, minutes: { letterMinutes($0, type, weekday: w) })
                : ""
            let key = type.name + "\n" + body
            if who[key] == nil { order.append(key) }
            who[key, default: []].append(w)
        }
        return order.map { key in
            let ws = who[key] ?? []
            let names = ws.map { Weekday.names[$0] }
            let list = names.count > 1 ? names.dropLast().joined(separator: ", ") + " y " + (names.last ?? "") : names.first ?? ""
            let parts = key.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            let body = parts.count > 1 ? String(parts[1]) : ""
            return "**\(list.capitalizedFirst) (\(parts.first ?? ""))**" + (body.isEmpty ? "" : "\n" + body)
        }.joined(separator: "\n\n")
    }

    /// Each date with changes of its own, with its hours that day.
    func aiDates() -> String {
        aiDateKeys().map { ds in
            let type = dayType(ds)
            let head = "**\(DayKey.long(ds)) (\(ds), \(type.name))**"
            guard isScheduled(ds) else { return head }
            let kind = scheduleKind(ds)
            return head + "\n" + aiTimeline(kind, time: { time(of: $0, on: ds) }, minutes: { letterMinutes($0, kind, on: ds) })
        }.joined(separator: "\n\n")
    }

    /// "La noche anterior / 10:25 pm Dormido", "Mañana / 5:55 SAVERS / 5:55 Silencio · 10 min", "Más tarde / …".
    private func aiTimeline(_ kind: DayType, time: (Step) -> String, minutes: (Letter) -> Int) -> String {
        guard let t = settings.schedule?.type(kind) else { return "" }
        let bedID = bedStep(kind)?.id
        var seen: Set<Letter> = []
        var lines: [String] = []
        for g in TypeSchedule.Group.allCases where !t[g].isEmpty {
            lines.append(g == .night ? "La noche anterior" : g == .later ? "Más tarde" : "Mañana")
            for st in t[g] {
                let at = time(st)
                let title = st.title ?? st.label
                var line = "- \(at.isEmpty ? "sin hora" : at) \(title)"
                if let detail = st.detail, !detail.isEmpty { line += " (\(detail))" }
                if st.id == bedID, let m = TimeText.minutes(at) {
                    line += " · prepararte desde \(TimeText.label((m - windDown + 1440) % 1440))"
                }
                let keys = st.letterKeys.filter { seen.insert($0).inserted }
                if keys.count == 1, keys[0].name == title {
                    let m = minutes(keys[0])
                    lines.append(line + (m > 0 ? " · \(m) min" : ""))
                    continue
                }
                lines.append(line)
                var start = TimeText.minutes(at)
                for k in keys {
                    let m = minutes(k)
                    lines.append("  - " + [start.map(TimeText.label), k.name, m > 0 ? "\(m) min" : nil].compactMap { $0 }.joined(separator: " ") )
                    if let s = start { start = s + m }
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: The record

    /// Totals per letter, then each day with SAVERS: what was marked and when. From the first day with a
    /// mark, so the weeks before the app don't read as days missed.
    func aiRecord(weeks: Int) -> String {
        let first = days.filter { $0.value.doneCount > 0 }.keys.min() ?? today
        let dates = (0..<(weeks * 7)).reversed().map { DayKey.adding(-$0, to: today) }.filter { $0 >= first }
        var lines: [String] = []
        var count = 0
        var complete = 0
        var perLetter: [Letter: Int] = [:]
        var anyHour = false
        for ds in dates {
            let type = dayType(ds)
            let d = day(ds)
            guard type.hasSavers || d.extra || d.doneCount > 0 else { continue }
            count += 1
            if d.doneCount == 6 { complete += 1 }
            for l in Letter.allCases where d.isDone(l) { perLetter[l, default: 0] += 1 }
            var line = "- \(DayKey.short(ds)) · \(type.name)" + (type.hasSavers ? "" : " (los hice igual)")
            let done = Letter.allCases.filter(d.isDone)
            let hours = done.map { l in (l, aiHour(d.checkedAt?[l.rawValue], ds: ds)) }
            if hours.contains(where: { $0.1 != nil }) {
                anyHour = true
                line += " · " + hours.map { [$0.0.name, $0.1].compactMap { $0 }.joined(separator: " ") }.joined(separator: ", ")
            } else if done.count == 6 {
                line += " · las 6"
            } else if !done.isEmpty {
                line += " · " + done.map(\.name).joined(separator: ", ")
            }
            let missing = Letter.allCases.filter { !d.isDone($0) }.map(\.name)
            if done.isEmpty {
                line += ds == today ? " · hoy, todavía nada marcado" : " · nada marcado"
            } else if !missing.isEmpty {
                line += ds == today ? " · hoy, todavía sin: " : " · faltó: "
                line += missing.joined(separator: ", ")
            }
            lines.append(line)
        }
        guard count > 0 else { return "Todavía no hay días registrados." }
        let totals = Letter.allCases.map { "\($0.name) \(perLetter[$0, default: 0])" }.joined(separator: ", ")
        var head = "Días con SAVERS: \(count). Completos: \(complete). Por letra: \(totals)."
        head += anyHour
            ? " La hora junto a cada letra es cuando la marqué en la app (puede ser después de hacerla)."
            : " La app todavía no guardaba a qué hora marco cada letra."
        return head + " Los sábados y los días sin SAVERS solo aparecen si los hice igual.\n\n" + lines.joined(separator: "\n")
    }

    /// "6:02", or "11:40 pm del Lun 28 sept" when it was marked on another day.
    private func aiHour(_ iso: String?, ds: String) -> String? {
        guard let date = Date(iso: iso) else { return nil }
        let p = DayKey.calendar.dateComponents([.hour, .minute], from: date)
        let label = TimeText.label((p.hour ?? 0) * 60 + (p.minute ?? 0))
        let on = DayKey.of(date)
        return on == ds ? label : "\(label) del \(DayKey.short(on))"
    }
}
