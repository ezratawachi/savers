import Foundation

/// A copy file (`savers-copia-AAAA-MM-DD.json`), read and checked before anything changes.
struct Backup {
    enum Part: String, CaseIterable {
        case name, affirmations, visualization, schedule

        var spoken: String {
            switch self {
            case .name: "tu nombre"
            case .affirmations: "tus afirmaciones"
            case .visualization: "tu visualización"
            case .schedule: "tu horario"
            }
        }
    }

    enum Problem: Error {
        case notACopy, empty

        var message: String {
            switch self {
            case .notACopy: "Ese archivo no es una copia de SAVERS"
            case .empty: "Esa copia no trae nada para importar"
            }
        }
    }

    /// What the copy's "paraLaIA" says, word for word as the web writes it.
    static let summaryNote = "\"resumen\" es solo para leer: la app lo calcula y al importar no lo usa. La hora de cada letra es la hora de su bloque más los minutos de las letras que van antes. " +
        "Para ajustar la rutina, cambia settings.schedule. En types.normal y types.gym, cada bloque tiene \"time\" (su hora todos los días de ese tipo), \"times\" (otra hora solo un día de la semana, como {\"jue\": \"5:10\"}) " +
        "y \"letters\" (qué letras van en ese bloque y en qué orden: silencio, afirmaciones, visualizacion, ejercicio, lectura, escritura). " +
        "Los minutos de Silencio y Lectura van en \"minutes\" ({\"silencio\": 10, \"lectura\": 4}) y \"minutesDays\" ({\"lectura\": {\"jue\": 10}}); los de Afirmaciones, Visualización, Ejercicio y Escritura no se pueden cambiar. " +
        "\"week\" dice qué es cada día (0 domingo … 5 viernes): \"normal\", \"gym\" u \"off\" (sin SAVERS); el sábado es Shabbat. " +
        "En settings.schedule, \"windDown\" son los minutos antes de Dormido en que llega el aviso de prepararte para dormir: uno para todas las noches, de 15 a 90 (si falta, 45). " +
        "Las horas se escriben \"5:20\" (de mañana) o \"8:50 pm\". Un cambio solo para una fecha va en days[\"AAAA-MM-DD\"]: \"times\" (por id de bloque) y \"mins\"."

    let settings: AppSettings
    /// Only what the file brings is replaced, so a schedule-only file never touches the affirmations.
    let parts: [Part]
    let days: [String: Day]
    /// The file's "resumen", only to warn about hours or minutes in it that importing won't keep.
    let resumen: [String: JSONValue]

    init(data: Data) throws(Problem) {
        guard let root = try? JSONDecoder().decode([String: JSONValue].self, from: data),
              root["app"] == .string("savers"), case .object(let rawSettings)? = root["settings"] else { throw .notACopy }
        let encoded = (try? Persistence.encoder.encode(rawSettings)) ?? Data()
        settings = (try? JSONDecoder().decode(AppSettings.self, from: encoded)) ?? AppSettings()
        parts = Part.allCases.filter { rawSettings[$0.rawValue] != nil }
        if case .object(let rawDays)? = root["days"] { days = Persistence.days(from: rawDays) } else { days = [:] }
        if case .object(let r)? = root["resumen"] { resumen = r } else { resumen = [:] }
        if parts.isEmpty && days.isEmpty { throw .empty }
    }

    /// "Se reemplaza solo tu horario." "Se agregan 12 días de registro; …", and what the summary says that won't stay.
    func summary(current: AppSettings) -> String {
        var lines: [String] = []
        let names = parts.map(\.spoken)
        if let last = names.last {
            let list = names.count > 1 ? names.dropLast().joined(separator: ", ") + " y " + last : last
            lines.append("Se reemplaza solo \(list).")
        } else {
            lines.append("Tus afirmaciones y tu horario no cambian.")
        }
        if !days.isEmpty {
            let n = days.count == 1 ? " 1 día" : "n \(days.count) días"
            lines.append("Se agrega\(n) de registro; si un día ya existe, se queda el más reciente.")
        }
        let changed = summaryChanges(current: current)
        if !changed.isEmpty {
            let shown = changed.prefix(3).joined(separator: ", ") + (changed.count > 3 ? " y \(changed.count - 3) más" : "")
            lines.append("En el resumen cambió \(shown), y eso no se guarda: esas horas y minutos los calcula la app. " +
                "Para moverlos, cambia la hora del bloque o los minutos de Silencio y Lectura.")
        }
        return lines.joined(separator: " ")
    }

    var doneMessage: String { parts == [.schedule] ? "Horario importado" : "Copia importada" }
}
