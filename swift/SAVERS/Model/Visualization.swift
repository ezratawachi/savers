import Foundation

/// The visualization questions and the note under them.
struct Visualization: Codable, Equatable, Sendable {
    var items: [Item]
    var note: String

    /// The questions someone starts with, in the app's language.
    static var standard: Visualization {
        Visualization(items: [
            Item(label: String(localized: "My day"), text: String(localized: "How do I see myself doing today's most important thing well?")),
            Item(label: String(localized: "My obstacle"), text: String(localized: "What is most likely to pull me off track today?")),
            Item(label: String(localized: "My plan"), text: String(localized: "If that happens, what will I do?")),
        ], note: "")
    }

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
