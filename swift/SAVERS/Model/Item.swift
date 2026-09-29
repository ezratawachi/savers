import Foundation

/// An affirmation or a visualization question: an optional title and its text.
struct Item: Codable, Hashable, Sendable {
    var label: String
    var text: String

    init(label: String = "", text: String) {
        self.label = label
        self.text = text
    }

    /// Older copies wrote plain strings in these lists.
    init(from decoder: Decoder) throws {
        if let s = try? decoder.singleValueContainer().decode(String.self) {
            self.init(text: s)
            return
        }
        let c = try decoder.container(keyedBy: AnyKey.self)
        self.init(label: c.lenient(String.self, "label") ?? "", text: c.lenient(String.self, "text") ?? "")
    }

    var isFilled: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

extension Array where Element == Item {
    var filled: [Item] { filter(\.isFilled) }
}
