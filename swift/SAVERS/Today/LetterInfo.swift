/// What a letter's card says: its line under the name, its minutes, and whether it opens.
struct LetterInfo {
    var subtitle: String
    var time: String
    var opens: Bool
}

extension Routine {
    func info(_ letter: Letter, on ds: String, reviewDue: Bool) -> LetterInfo {
        let kind = scheduleKind(ds)
        let mins = "\(letterMinutes(letter, kind, on: ds)) min"
        switch letter {
        case .silencio:
            return LetterInfo(subtitle: "Daily Calm", time: mins, opens: false)
        case .afirmaciones:
            let review = !settings.affirmations.filled.isEmpty && reviewDue
            return LetterInfo(subtitle: review ? "Toca revisarlas" : "En voz alta", time: mins, opens: true)
        case .visualizacion:
            return LetterInfo(subtitle: "Ojos cerrados, guiada", time: mins, opens: true)
        case .ejercicio:
            if kind == .gym {
                let span = TimeText.span(settings.schedule?.gymTime).map { "\($0) min" } ?? "Gym"
                return LetterInfo(subtitle: "Gym con tu entrenador", time: span, opens: false)
            }
            return LetterInfo(subtitle: "Rutina en casa", time: "8 min", opens: true)
        case .lectura:
            return LetterInfo(subtitle: kind == .gym ? "Tu libro" : "Con tu café", time: mins, opens: true)
        case .escritura:
            return LetterInfo(subtitle: "Agradecer y anotar", time: mins, opens: true)
        }
    }
}
