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

    let settings: AppSettings
    /// Only what the file brings is replaced, so a schedule-only file never touches the affirmations.
    let parts: [Part]
    let days: [String: Day]

    init(data: Data) throws(Problem) {
        guard let root = try? JSONDecoder().decode([String: JSONValue].self, from: data),
              root["app"] == .string("savers"), case .object(let rawSettings)? = root["settings"] else { throw .notACopy }
        let encoded = (try? Persistence.encoder.encode(rawSettings)) ?? Data()
        settings = (try? JSONDecoder().decode(AppSettings.self, from: encoded)) ?? AppSettings()
        parts = Part.allCases.filter { rawSettings[$0.rawValue] != nil }
        if case .object(let rawDays)? = root["days"] { days = Persistence.days(from: rawDays) } else { days = [:] }
        if parts.isEmpty && days.isEmpty { throw .empty }
    }

    /// "Se reemplaza solo tu horario." "Se agregan 12 días de registro; …"
    var summary: String {
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
        return lines.joined(separator: " ")
    }

    var doneMessage: String { parts == [.schedule] ? "Horario importado" : "Copia importada" }
}
