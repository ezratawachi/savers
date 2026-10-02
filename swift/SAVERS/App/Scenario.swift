#if DEBUG
import Foundation

/// A state to open the app in, for checking the design: `-escenario hechas`. Made-up data in a folder of its own,
/// with no cloud and no notices, so nothing real is read or changed. Debug builds only.
enum Scenario: String, CaseIterable {
    case manana, abiertas, hechas, diaCompleto = "dia-completo", shabbat, sinSavers = "sin-savers", historial, ajustes

    static let current: Scenario? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-escenario"), i + 1 < args.count else { return nil }
        return Scenario(rawValue: args[i + 1])
    }()

    /// `-pegar archivo`: a reply from an AI, read as if it had been pasted in Hablar con una IA (once).
    static var pasted: String? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-pegar"), i + 1 < args.count else { return nil }
        return try? String(contentsOfFile: args[i + 1], encoding: .utf8)
    }()

    /// `-paquete archivo`: where Hablar con una IA writes what "Mandar a la IA" would send, to read it.
    static let packetPath: String? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-paquete"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }()

    /// The prefs every part of the app uses in a scenario, emptied at launch.
    static let prefs: LocalPrefs = {
        let d = UserDefaults(suiteName: "savers.escenario")!
        d.removePersistentDomain(forName: "savers.escenario")
        return LocalPrefs(defaults: d)
    }()

    var tab: AppTab {
        switch self {
        case .historial: .history
        case .ajustes: .settings
        default: .today
        }
    }

    /// Cards open on Hoy.
    var openCards: Set<Letter> {
        switch self {
        case .abiertas: [.afirmaciones, .visualizacion, .escritura]
        case .hechas: [.afirmaciones]
        default: []
        }
    }

    var foldOpen: Bool { self == .hechas }

    /// Days to move "today" by: Shabbat is the next Saturday.
    var dayShift: Int {
        guard self == .shabbat else { return 0 }
        return (6 - DayKey.weekday(DayKey.of(.now)) + 7) % 7
    }

    func makeStore() -> AppStore {
        DayKey.shift = dayShift
        let folder = URL.temporaryDirectory.appending(path: "escenario", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: folder)
        let persistence = Persistence(folder: folder)
        let settings = try! JSONDecoder().decode(AppSettings.self, from: Data(Self.settingsJSON.utf8))
        try? persistence.save(settings: settings, days: days())
        return AppStore(persistence: persistence, prefs: Self.prefs)
    }

    private func days() -> [String: Day] {
        let today = DayKey.today
        var out: [String: Day] = [:]
        // Three weeks behind, all done but two days, for the streak and Historial.
        for back in 1...21 {
            let ds = DayKey.adding(-back, to: today)
            var d = Day(date: ds)
            let skipped = back == 9 || back == 16
            for l in Letter.allCases where !skipped || l == .ejercicio { d.checks[l.rawValue] = true }
            if back % 3 == 0 { d.gratitude = "Una caminata tranquila con la familia." }
            out[ds] = d
        }
        var d = Day(date: today)
        let morning: [Letter] = [.ejercicio, .silencio, .afirmaciones, .visualizacion, .escritura]
        switch self {
        case .manana:
            d.type = "normal"
        case .abiertas:
            d.type = "gym"
            d.checks = ["ejercicio": true]
            d.gratitude = "El café de la mañana en silencio, porque me ordena el día."
            d.bookIdea = "Los hábitos pequeños se suman más de lo que parece."
        case .hechas:
            d.type = "gym"
            for l in morning { d.checks[l.rawValue] = true }
        case .diaCompleto:
            d.type = "gym"
            for l in Letter.allCases { d.checks[l.rawValue] = true }
        case .sinSavers:
            d.type = "off"
        case .shabbat, .historial, .ajustes:
            break
        }
        out[today] = d
        return out
    }

    private static let settingsJSON = """
    {"name": "Prueba", "readApp": "libros",
     "affirmations": ["Hoy empiezo el día con calma y con intención.",
                      "Cumplo lo que prometo, paso a paso.",
                      "Estoy presente con la gente que quiero."],
     "schedule": {
      "gymReading": "miércoles 8:50 pm", "gymTime": "5:15–6:00",
      "week": {"0": "off", "1": "normal", "2": "normal", "3": "gym", "4": "normal", "5": "gym"},
      "types": {
       "gym": {"minutes": {"lectura": 10},
        "night": [{"id": "gym-night-0", "time": "9:40 pm", "title": "Dormido"}],
        "steps": [{"id": "gym-steps-0", "time": "4:40", "title": "Te paras", "detail": "tu rato de café"},
                  {"id": "gym-steps-1", "time": "5:15", "title": "Gym con tu entrenador", "short": "Gym", "letters": ["ejercicio"]},
                  {"id": "gym-steps-2", "time": "6:05", "title": "SAVERS", "short": "SAVERS",
                   "letters": ["silencio", "afirmaciones", "visualizacion", "escritura"]},
                  {"id": "gym-steps-3", "time": "6:25", "title": "Baño", "short": "Baño"}],
        "later": [{"id": "gym-later-0", "time": "8:50 pm", "title": "Lectura", "letters": ["lectura"]}]},
       "normal": {"minutes": {"lectura": 10},
        "night": [{"id": "normal-night-0", "time": "10:25 pm", "title": "Dormido"}],
        "steps": [{"id": "normal-steps-0", "time": "5:25", "title": "Te paras", "detail": "tu rato de café"},
                  {"id": "normal-steps-1", "time": "5:55", "title": "SAVERS", "short": "SAVERS",
                   "letters": ["silencio", "lectura", "afirmaciones", "visualizacion", "ejercicio", "escritura"]},
                  {"id": "normal-steps-2", "time": "6:35", "title": "Baño", "short": "Baño"}],
        "later": []}}}}
    """
}
#endif
