/// Escritura's three fields.
enum WritingField: String, CaseIterable, Identifiable, Sendable {
    case gratitude, bookIdea, notes

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gratitude: "Agradezco"
        case .bookIdea: "Del libro"
        case .notes: "Notas"
        }
    }

    func hint(gym: Bool) -> String {
        switch self {
        case .gratitude: "algo concreto de ayer y por qué"
        case .bookIdea: gym ? "una idea de lo que leíste ayer" : "una idea de lo que leíste hoy"
        case .notes: "opcional"
        }
    }
}
