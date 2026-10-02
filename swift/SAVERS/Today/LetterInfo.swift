import Foundation

/// What a letter's card says: its line under the name, its minutes, and whether it opens.
struct LetterInfo {
    var subtitle: String
    var time: String
    var opens: Bool
}

extension Routine {
    func info(_ letter: Letter, on ds: String, reviewDue: Bool) -> LetterInfo {
        let kind = scheduleKind(ds)
        let mins = String(localized: "\(letterMinutes(letter, kind, on: ds)) min")
        switch letter {
        case .silencio:
            return LetterInfo(subtitle: settings.breatheLine, time: mins, opens: false)
        case .afirmaciones:
            let review = !settings.affirmations.filled.isEmpty && reviewDue
            return LetterInfo(subtitle: review ? String(localized: "Time to review them") : String(localized: "Out loud"), time: mins, opens: true)
        case .visualizacion:
            return LetterInfo(subtitle: String(localized: "Eyes closed, guided"), time: mins, opens: true)
        case .ejercicio:
            if kind == .gym {
                let span = TimeText.span(settings.schedule?.gymTime).map { String(localized: "\($0) min") } ?? String(localized: "Gym")
                return LetterInfo(subtitle: String(localized: "Gym with your trainer"), time: span, opens: false)
            }
            return LetterInfo(subtitle: String(localized: "Home routine"), time: String(localized: "\(8) min"), opens: true)
        case .lectura:
            return LetterInfo(subtitle: kind == .gym ? String(localized: "Your book") : String(localized: "With your coffee"), time: mins, opens: true)
        case .escritura:
            return LetterInfo(subtitle: String(localized: "Give thanks and jot down"), time: mins, opens: true)
        }
    }
}
