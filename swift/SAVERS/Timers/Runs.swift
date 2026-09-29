import Foundation
import Observation
import UIKit

/// A guided timer in progress: `savers:timer[:vis]` = `{base, runStart, running, day}`.
/// Time comes from the clock (base + now − runStart), not from counting ticks, so it survives iOS pausing the app.
struct GuidedRun: Codable {
    var base: Double = 0
    /// Milliseconds, like the web.
    var runStart: Double = 0
    var running = false
    var day = ""

    func elapsed(_ now: Date) -> Double {
        base + (running ? max(0, now.timeIntervalSince1970 - runStart / 1000) : 0)
    }
}

/// A reading in progress: `savers:reading` = `{day, start, min, notify, sent}`. The minutes stay as they were at the start.
struct ReadingRun: Codable {
    var day: String
    var start: Double
    var min: Int
    var notify = true
    var sent: Bool?

    func left(_ now: Date) -> Int {
        max(0, Int((Double(min) * 60 - (now.timeIntervalSince1970 - start / 1000)).rounded(.up)))
    }
}

/// One step of a guided timer.
struct RunStep {
    var secs: Double
    var text: String
}

/// The guided timers and the reading. Only one timer runs at a time; the screen stays on while it does.
@Observable
final class Runs {
    /// Moves every quarter second while something runs, so the views follow the clock.
    private(set) var now = Date.now
    private(set) var vis: GuidedRun?
    private(set) var reading: ReadingRun?

    @ObservationIgnored private let store: AppStore
    @ObservationIgnored private let toast: Toast
    @ObservationIgnored private let prefs: LocalPrefs
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var lastIdx = 0
    @ObservationIgnored private var lastRemain: Int?

    static let visSecs = 60.0

    init(store: AppStore, toast: Toast, prefs: LocalPrefs = .standard) {
        self.store = store
        self.toast = toast
        self.prefs = prefs
        restore()
    }

    // MARK: Visualización

    var visSteps: [RunStep] {
        store.settings.visualization.items.filled.map { RunStep(secs: Self.visSecs, text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    func total(_ steps: [RunStep]) -> Double { steps.reduce(0) { $0 + $1.secs } }

    func stepStart(_ steps: [RunStep], _ i: Int) -> Double { steps.prefix(i).reduce(0) { $0 + $1.secs } }

    func stepAt(_ steps: [RunStep], _ el: Double) -> Int {
        var i = 0, t = 0.0
        while i < steps.count - 1 && el >= t + steps[i].secs {
            t += steps[i].secs
            i += 1
        }
        return i
    }

    /// Empezar / Seguir / Repetir.
    func startVis() {
        let steps = visSteps
        guard !steps.isEmpty else { return }
        let fresh = vis == nil
        var r = vis ?? GuidedRun(day: store.today)
        r.running = true
        r.runStart = Date.now.timeIntervalSince1970 * 1000
        vis = r
        lastRemain = nil
        if fresh {
            lastIdx = 0
            enterVis(0, start: true)
        } else {
            Sounds.beep(880, 0.15)
        }
        changed()
    }

    func pauseVis() {
        guard var r = vis else { return }
        r.base = r.elapsed(.now)
        r.running = false
        vis = r
        Voice.shared.stop()
        changed()
    }

    func resetVis() {
        vis = nil
        lastIdx = 0
        lastRemain = nil
        Voice.shared.stop()
        changed()
    }

    /// Siguiente: straight to the next question, or the end from the last one.
    func skipVis() {
        let steps = visSteps
        guard !steps.isEmpty else { return }
        // Before starting it moves to the next question and waits there, paused.
        var r = vis ?? GuidedRun(day: store.today)
        let idx = stepAt(steps, r.elapsed(.now))
        guard idx < steps.count - 1 else {
            vis = r
            finishVis()
            return
        }
        r.base = stepStart(steps, idx + 1)
        r.runStart = Date.now.timeIntervalSince1970 * 1000
        vis = r
        lastIdx = idx + 1
        lastRemain = nil
        enterVis(idx + 1, start: false)
        changed()
    }

    private func enterVis(_ i: Int, start: Bool) {
        let steps = visSteps
        guard steps.indices.contains(i) else { return }
        if start { Sounds.beep(880, 0.15) } else { Sounds.bell() }
        Voice.shared.say(steps[i].text, .calm)
    }

    private func finishVis() {
        let day = vis?.day ?? store.today
        vis = nil
        lastIdx = 0
        lastRemain = nil
        changed()
        Sounds.bell()
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            Voice.shared.say("Visualización lista.", .notice)
        }
        store.mark(.visualizacion, on: day)
        toast.show("Visualización lista y marcada")
    }

    private func tickVis() {
        guard let r = vis, r.running else { return }
        let steps = visSteps
        guard !steps.isEmpty else { resetVis(); return }
        let el = r.elapsed(now)
        if el >= total(steps) { finishVis(); return }
        let idx = stepAt(steps, el)
        if idx != lastIdx {
            lastIdx = idx
            lastRemain = nil
            enterVis(idx, start: false)
        } else {
            let remain = Int((stepStart(steps, idx) + steps[idx].secs - el).rounded(.up))
            if remain != lastRemain {
                lastRemain = remain
                if remain == 10 { Sounds.softTone() }
            }
        }
    }

    // MARK: Lectura

    func readingMinutes() -> Int {
        let r = store.routine
        return r.letterMinutes(.lectura, r.scheduleKind(store.today), on: store.today)
    }

    /// Saves the start, sets the "Lectura terminada" notice, and opens the reading app.
    func startReading() {
        let run = ReadingRun(day: store.today, start: Date.now.timeIntervalSince1970 * 1000, min: readingMinutes())
        reading = run
        changed()
        Task {
            guard await LocalNote.allowed() else { return }
            let min = run.min
            await LocalNote.schedule(
                id: "lectura",
                at: Date(timeIntervalSince1970: run.start / 1000 + Double(min) * 60),
                title: "Lectura terminada",
                body: "Leíste \(min) \(min == 1 ? "minuto" : "minutos"). Se marca sola al volver a SAVERS."
            )
            if reading?.start == run.start { reading?.sent = true; save() }
        }
        if let url = ReadApp(store.settings.readApp).url { UIApplication.shared.open(url) }
    }

    /// Cancelar: the notice goes with it.
    func cancelReading() {
        LocalNote.cancel("lectura")
        reading = nil
        changed()
    }

    /// Ya terminé, or the time ran out.
    func finishReading() {
        guard let r = reading else { return }
        LocalNote.cancel("lectura")
        reading = nil
        changed()
        guard store.mark(.lectura, on: r.day) else { return }
        if store.routine.day(r.day).doneCount == 6 { Sounds.complete() } else { Sounds.check() }
        toast.show("Lectura marcada")
    }

    // MARK: Keeping time

    /// When the app comes back: a new day drops yesterday's timers; a finished reading gets marked.
    func resume() {
        now = .now
        if let r = vis, r.day != store.today { resetVis() }
        if let r = reading, r.day != store.today { reading = nil; changed() }
        tick()
        syncTicker()
    }

    private func tick() {
        now = .now
        tickVis()
        if let r = reading, r.left(now) == 0 { finishReading() }
    }

    private var active: Bool { vis?.running == true || reading != nil }

    private func syncTicker() {
        UIApplication.shared.isIdleTimerDisabled = vis?.running == true
        if active {
            guard ticker == nil else { return }
            ticker = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(250))
                    tick()
                }
            }
        } else {
            ticker?.cancel()
            ticker = nil
        }
    }

    private func changed() {
        now = .now
        save()
        syncTicker()
    }

    private func save() {
        prefs["timer:vis"] = vis.flatMap(Self.json)
        prefs["reading"] = reading.flatMap(Self.json)
    }

    private func restore() {
        let today = store.today
        if let r: GuidedRun = Self.decode(prefs["timer:vis"]), r.day == today, !visSteps.isEmpty,
           r.elapsed(.now) < total(visSteps) + 600 {
            vis = r
            lastIdx = stepAt(visSteps, min(r.elapsed(.now), total(visSteps) - 0.001))
        }
        if let r: ReadingRun = Self.decode(prefs["reading"]), r.day == today { reading = r }
        save()
        syncTicker()
    }

    private static func json<T: Encodable>(_ v: T) -> String? {
        (try? JSONEncoder().encode(v)).flatMap { String(data: $0, encoding: .utf8) }
    }

    private static func decode<T: Decodable>(_ s: String?) -> T? {
        s.flatMap { try? JSONDecoder().decode(T.self, from: Data($0.utf8)) }
    }
}

/// Where you read: `settings.readApp`.
struct ReadApp {
    let name: String
    let url: URL?

    init(_ key: String) {
        switch key {
        case "kindle": name = "Kindle"; url = URL(string: "kindle://")
        case "papel": name = "Libro físico"; url = nil
        default: name = "Libros"; url = URL(string: "ibooks://")
        }
    }
}
