import Foundation

/// What a letter's card says: its line under the name, its minutes, and whether it opens.
struct LetterInfo {
    var subtitle: String
    var time: String
    var opens: Bool
}

extension Routine {
    func info(_ letter: Letter, on ds: String, reviewDue: Bool) -> LetterInfo {
        var info = usualInfo(letter, on: ds, reviewDue: reviewDue)
        // In a block of its own ("5:15 · Gym", "Más tarde · 8:50 pm"): that block's name and hour.
        if let p = placement(letter, on: ds) {
            if p.step.onlyStep != letter { info.subtitle = p.step.title ?? p.step.label }
            if !p.time.isEmpty { info.time = p.time }
        }
        return info
    }

    private func usualInfo(_ letter: Letter, on ds: String, reviewDue: Bool) -> LetterInfo {
        let mins = String(localized: "\(letterMinutes(letter, scheduleKind(ds), on: ds)) min")
        switch letter {
        case .silencio:
            return LetterInfo(subtitle: settings.breatheLine, time: mins, opens: false)
        case .afirmaciones:
            let review = !settings.affirmations.filled.isEmpty && reviewDue
            return LetterInfo(subtitle: review ? String(localized: "Time to review them") : String(localized: "Out loud"), time: mins, opens: true)
        case .visualizacion:
            return LetterInfo(subtitle: String(localized: "Eyes closed, guided"), time: mins, opens: true)
        case .ejercicio:
            return LetterInfo(subtitle: String(localized: "Home routine"), time: mins, opens: true)
        case .lectura:
            let own = placement(.lectura, on: ds) != nil
            return LetterInfo(subtitle: own ? String(localized: "Your book") : String(localized: "With your coffee"), time: mins, opens: true)
        case .escritura:
            return LetterInfo(subtitle: String(localized: "Give thanks and jot down"), time: mins, opens: true)
        }
    }
}
