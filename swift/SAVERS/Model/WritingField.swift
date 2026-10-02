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

    func hint(gym: Bool) -> String {
        switch self {
        case .gratitude: String(localized: "something specific from yesterday, and why")
        case .bookIdea: gym ? String(localized: "an idea from what you read yesterday") : String(localized: "an idea from what you read today")
        case .notes: String(localized: "optional")
        }
    }
}
