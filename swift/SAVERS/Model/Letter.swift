import Foundation

/// The six steps of the sunrise, in their fixed order. The raw value is the key used in the JSON, from
/// when they were SAVERS' letters.
enum Letter: String, CaseIterable, Codable, Identifiable, Sendable {
    case silencio, afirmaciones, visualizacion, ejercicio, lectura, escritura

    var id: String { rawValue }

    /// The name's first letter: none repeats.
    var initial: String { String(name.prefix(1)) }

    var name: String {
        switch self {
        case .silencio: String(localized: "Breathe")
        case .afirmaciones: String(localized: "Affirm")
        case .visualizacion: String(localized: "Imagine")
        case .ejercicio: String(localized: "Move")
        case .lectura: String(localized: "Read")
        case .escritura: String(localized: "Write")
        }
    }

    /// Its name in every language the app speaks, and its key: to read a block's title or what an AI wrote.
    var knownNames: [String] {
        switch self {
        case .silencio: ["Breathe", "Respira", rawValue]
        case .afirmaciones: ["Affirm", "Afirma", rawValue]
        case .visualizacion: ["Imagine", "Imagina", rawValue]
        case .ejercicio: ["Move", "Muévete", rawValue]
        case .lectura: ["Read", "Lee", rawValue]
        case .escritura: ["Write", "Escribe", rawValue]
        }
    }

    /// Breathe and Read last what you set; the others take what's in them.
    var usualMinutes: Int? {
        switch self {
        case .silencio: 10
        case .lectura: 4
        default: nil
        }
    }
}
