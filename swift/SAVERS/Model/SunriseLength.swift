import Foundation

/// How long the whole sunrise lasts, chosen the first time the app opens: 10, 20 or 30 minutes. Always the
/// six steps; a shorter sunrise makes each one shorter. Copies from before had none, and keep the app's
/// usual minutes.
enum SunriseLength: Int, CaseIterable, Codable, Identifiable, Sendable {
    case ten = 10, twenty = 20, thirty = 30

    var id: Int { rawValue }

    /// The next one up, for "Want more time?".
    var longer: SunriseLength? {
        switch self {
        case .ten: .twenty
        case .twenty: .thirty
        case .thirty: nil
        }
    }

    /// Breathe's and Read's minutes when the schedule doesn't set its own.
    func minutes(_ letter: Letter) -> Int? {
        switch (self, letter) {
        case (.ten, .silencio): 2
        case (.twenty, .silencio): 5
        case (.thirty, .silencio): 8
        case (.ten, .lectura): 1
        case (.twenty, .lectura): 6
        case (.thirty, .lectura): 7
        default: nil
        }
    }

    /// Move at home: the 2-minute routine, or the whole 8.
    var shortMove: Bool { self != .thirty }

    /// Seconds Imagine gives each question.
    var imagineSeconds: Double { self == .ten ? 40 : 60 }

    /// Write: a line of thanks and one idea.
    var writeMinutes: Int { self == .ten ? 1 : 2 }

    /// "10 min", for the choice and the question.
    var label: String { String(localized: "\(rawValue) min") }
}
