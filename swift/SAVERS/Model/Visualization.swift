/// The visualization questions and the note under them.
struct Visualization: Codable, Equatable, Sendable {
    var items: [Item]
    var note: String

    static let standard = Visualization(items: [
        Item(label: "Mi día", text: "¿Cómo me veo haciendo bien lo más importante de hoy?"),
        Item(label: "Mi obstáculo", text: "¿Qué es lo que más probablemente me saque del camino hoy?"),
        Item(label: "Mi plan", text: "Si pasa eso, ¿qué hago?"),
    ], note: "")

    /// The old default note, removed from copies that still carry it untouched.
    private static let oldNote = "Un minuto por pregunta, con los ojos cerrados. Si la mente se queda en blanco, respóndelas en voz baja."

    init(items: [Item], note: String) {
        self.items = items
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        let list = c.lenient([Item].self, "items") ?? []
        items = list.isEmpty ? Self.standard.items : list
        let n = c.lenient(String.self, "note") ?? ""
        note = n == Self.oldNote ? "" : n
    }
}
