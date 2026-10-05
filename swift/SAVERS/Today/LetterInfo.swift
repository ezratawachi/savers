import Foundation

/// What a letter's card says: its line under the name, its minutes, and whether it opens.
struct LetterInfo {
    var subtitle: String
    var time: String
    var opens: Bool
}

extension Routine {
    func info(_ letter: Letter, on ds: String) -> LetterInfo {
        var info = usualInfo(letter, on: ds)
        // In a block of its own ("5:15 · Gym", "Más tarde · 8:50 pm"): that block's hour.
        if let p = placement(letter, on: ds), !p.time.isEmpty { info.time = p.time }
        return info
    }

    private func usualInfo(_ letter: Letter, on ds: String) -> LetterInfo {
        let mins = String(localized: "\(letterMinutes(letter, scheduleKind(ds), on: ds)) min")
        switch letter {
        case .silencio:
            return LetterInfo(subtitle: String(localized: "Meditate or pray"), time: mins, opens: false)
        case .afirmaciones:
            return LetterInfo(subtitle: String(localized: "Your lines, out loud"), time: mins, opens: true)
        case .visualizacion:
            return LetterInfo(subtitle: String(localized: "Eyes closed, see your day"), time: mins, opens: true)
        case .ejercicio:
            return LetterInfo(subtitle: String(localized: "Wake up your body"), time: mins, opens: true)
        case .lectura:
            return LetterInfo(subtitle: String(localized: "A few pages to grow"), time: mins, opens: true)
        case .escritura:
            return LetterInfo(subtitle: String(localized: "Give thanks, note one idea"), time: mins, opens: true)
        }
    }
}
