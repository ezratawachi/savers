import Foundation

/// The sunrise's three moments, only for teaching (the welcome and The method), never in Today: the icon's
/// layers, night, horizon and sun.
enum Moment: String, CaseIterable, Identifiable {
    case still, aim, grow

    var id: String { rawValue }

    var name: String {
        switch self {
        case .still: String(localized: "Still")
        case .aim: String(localized: "Aim")
        case .grow: String(localized: "Grow")
        }
    }

    var steps: [Letter] {
        switch self {
        case .still: [.silencio]
        case .aim: [.afirmaciones, .visualizacion]
        case .grow: [.ejercicio, .lectura, .escritura]
        }
    }

    /// What the moment is for, in one line.
    var about: String {
        switch self {
        case .still: String(localized: "Start without noise.")
        case .aim: String(localized: "Choose who you'll be and what matters today.")
        case .grow: String(localized: "Body, mind and memory, a little each day.")
        }
    }
}
