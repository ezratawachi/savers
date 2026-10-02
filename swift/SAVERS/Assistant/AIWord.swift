/// The configuration's words, in the app's language: they're names the AI writes back, so they stay out of the
/// translations. Reading what it pastes accepts either language (`AIProposal`).
enum AIWord {
    static var readOn: String { pick("leerEn", "readOn") }
    static var affirmations: String { pick("afirmaciones", "affirmations") }
    static var visualization: String { pick("visualizacion", "visualization") }
    static var questions: String { pick("preguntas", "questions") }
    static var note: String { pick("nota", "note") }
    static var week: String { pick("semana", "week") }
    static var windDown: String { pick("prepararte", "windDown") }
    static var dates: String { pick("fechas", "dates") }
    static var hours: String { pick("horas", "hours") }
    static var hoursByDay: String { pick("horasPorDia", "hoursByDay") }
    static var minutes: String { pick("minutos", "minutes") }
    static var minutesByDay: String { pick("minutosPorDia", "minutesByDay") }
    static var type: String { pick("tipo", "type") }
    static var title: String { pick("titulo", "title") }
    static var text: String { pick("texto", "text") }

    /// "libros" → "books": how the configuration names a way of reading.
    static func readApp(_ key: String) -> String {
        guard !AppLanguage.isSpanish else { return key }
        return ["libros": "books", "papel": "paper"][key] ?? key
    }

    /// "jueves", "thursday"
    static func weekday(_ w: Int) -> String { Weekday.names[w].lowercased() }

    private static func pick(_ es: String, _ en: String) -> String { AppLanguage.isSpanish ? es : en }
}
