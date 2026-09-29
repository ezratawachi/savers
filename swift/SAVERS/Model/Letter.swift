/// The six letters, in their fixed order. The raw value is the key used in the JSON.
enum Letter: String, CaseIterable, Codable, Identifiable, Sendable {
    case silencio, afirmaciones, visualizacion, ejercicio, lectura, escritura

    var id: String { rawValue }

    var initial: String {
        switch self {
        case .silencio, .escritura: "S"
        case .afirmaciones: "A"
        case .visualizacion: "V"
        case .ejercicio: "E"
        case .lectura: "R"
        }
    }

    var name: String {
        switch self {
        case .silencio: "Silencio"
        case .afirmaciones: "Afirmaciones"
        case .visualizacion: "Visualización"
        case .ejercicio: "Ejercicio"
        case .lectura: "Lectura"
        case .escritura: "Escritura"
        }
    }

    /// Silencio and Lectura last what you set; the others take what's in them.
    var usualMinutes: Int? {
        switch self {
        case .silencio: 10
        case .lectura: 4
        default: nil
        }
    }
}
