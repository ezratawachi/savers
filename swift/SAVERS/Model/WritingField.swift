import Foundation

/// Write's three fields.
enum WritingField: String, CaseIterable, Identifiable, Sendable {
    case gratitude, bookIdea, notes

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gratitude: String(localized: "Grateful for")
        case .bookIdea: String(localized: "From the book")
        case .notes: String(localized: "Notes")
        }
    }

    /// `readFirst`: Read comes before Write that day, so the idea is from today's reading.
    func hint(readFirst: Bool) -> String {
        switch self {
        case .gratitude: String(localized: "something specific from yesterday, and why")
        case .bookIdea: readFirst ? String(localized: "an idea from what you read today") : String(localized: "an idea from what you read yesterday")
        case .notes: String(localized: "optional")
        }
    }
}
