/// The six steps of the sunrise, in their fixed order. The raw value is the key used in the JSON, from
/// when they were SAVERS' letters.
enum Letter: String, CaseIterable, Codable, Identifiable, Sendable {
    case silencio, afirmaciones, visualizacion, ejercicio, lectura, escritura

    var id: String { rawValue }

    /// The name's first letter: none repeats.
    var initial: String { String(name.prefix(1)) }

    var name: String {
        switch self {
        case .silencio: "Respira"
        case .afirmaciones: "Afirma"
        case .visualizacion: "Imagina"
        case .ejercicio: "Muévete"
        case .lectura: "Lee"
        case .escritura: "Escribe"
        }
    }

    /// Respira and Lee last what you set; the others take what's in them.
    var usualMinutes: Int? {
        switch self {
        case .silencio: 10
        case .lectura: 4
        default: nil
        }
    }
}
