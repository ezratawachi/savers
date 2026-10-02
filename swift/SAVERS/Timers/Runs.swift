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

/// The two guided timers.
enum RunKind: CaseIterable {
    case ejercicio, visualizacion

    var letter: Letter { self == .ejercicio ? .ejercicio : .visualizacion }
    var storeKey: String { self == .ejercicio ? "timer" : "timer:vis" }
}

/// The guided timers and the reading. Only one timer runs at a time; the screen stays on while it does.
@Observable
final class Runs {
    /// Moves every quarter second while something runs, so the views follow the clock.
    private(set) var now = Date.now
    private(set) var ex: GuidedRun?
    private(set) var vis: GuidedRun?
    private(set) var reading: ReadingRun?

    @ObservationIgnored private let store: AppStore
    @ObservationIgnored private let toast: Toast
    @ObservationIgnored private let notices: Notices
    @ObservationIgnored private let prefs: LocalPrefs
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var lastIdx: [RunKind: Int] = [:]
    @ObservationIgnored private var lastRemain: [RunKind: Int] = [:]
    /// Where the exercise guide has queued its sounds up to, in routine seconds.
    @ObservationIgnored private var guideFrom: Double?

    /// Guide sounds are queued this far ahead on the audio clock, so the rhythm doesn't depend on the ticker.
    private static let guideAhead = 0.6

    init(store: AppStore, toast: Toast, notices: Notices, prefs: LocalPrefs = .standard) {
        self.store = store
        self.toast = toast
        self.notices = notices
        self.prefs = prefs
        restore()
    }

    // MARK: Steps

    var visSteps: [RunStep] {
        let secs = store.settings.length?.imagineSeconds ?? 60
        return store.settings.visualization.items.filled.map { RunStep(secs: secs, text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    /// Move at home: the short routine or the whole one, as the sunrise's length says.
    var workout: Workout { .of(store.settings) }

    func steps(_ k: RunKind) -> [RunStep] { k == .ejercicio ? workout.runSteps : visSteps }

    func run(_ k: RunKind) -> GuidedRun? { k == .ejercicio ? ex : vis }

    private func set(_ k: RunKind, _ r: GuidedRun?) {
        if k == .ejercicio { ex = r } else { vis = r }
    }

    static func total(_ steps: [RunStep]) -> Double { steps.reduce(0) { $0 + $1.secs } }

    static func stepStart(_ steps: [RunStep], _ i: Int) -> Double { steps.prefix(i).reduce(0) { $0 + $1.secs } }

    static func stepAt(_ steps: [RunStep], _ el: Double) -> Int {
        var i = 0, t = 0.0
        while i < steps.count - 1 && el >= t + steps[i].secs {
            t += steps[i].secs
            i += 1
        }
        return i
    }

    // MARK: Buttons

    /// Empezar / Seguir / Repetir.
    func start(_ k: RunKind) {
        let steps = steps(k)
        guard !steps.isEmpty else { return }
        for other in RunKind.allCases where other != k && run(other)?.running == true { pause(other) }
        let fresh = run(k) == nil
        var r = run(k) ?? GuidedRun(day: store.today)
        r.running = true
        r.runStart = Date.now.timeIntervalSince1970 * 1000
        set(k, r)
        lastRemain[k] = nil
        if k == .ejercicio { guideStop(from: nil) }
        ToneEngine.shared.timerRunning = true
        if fresh {
            lastIdx[k] = 0
            enter(k, 0, .start)
        } else {
            Sounds.beep(880, 0.15)
        }
        changed()
    }

    func pause(_ k: RunKind) {
        guard var r = run(k) else { return }
        r.base = r.elapsed(.now)
        r.running = false
        set(k, r)
        if k == .ejercicio { guideStop(from: nil) }
        Voice.shared.stop()
        changed()
    }

    func reset(_ k: RunKind) {
        set(k, nil)
        lastIdx[k] = 0
        lastRemain[k] = nil
        if k == .ejercicio { guideStop(from: nil) }
        Voice.shared.stop()
        changed()
    }

    /// Siguiente: straight to the next step, or the end from the last one.
    func skip(_ k: RunKind) {
        let steps = steps(k)
        guard !steps.isEmpty else { return }
        // Before starting it moves to the next step and waits there, paused.
        var r = run(k) ?? GuidedRun(day: store.today)
        let idx = Self.stepAt(steps, r.elapsed(.now))
        guard idx < steps.count - 1 else {
            set(k, r)
            finish(k)
            return
        }
        r.base = Self.stepStart(steps, idx + 1)
        r.runStart = Date.now.timeIntervalSince1970 * 1000
        set(k, r)
        lastIdx[k] = idx + 1
        lastRemain[k] = nil
        if k == .ejercicio {
            // From where the skip lands, so the drill's first word isn't missed.
            guideStop(from: r.base)
            if r.running { guidePump(r.base) }
        }
        enter(k, idx + 1, .skip)
        changed()
    }

    // MARK: What each timer does

    private enum Entry { case start, skip, auto }

    private func enter(_ k: RunKind, _ i: Int, _ how: Entry) {
        switch k {
        case .visualizacion:
            let steps = visSteps
            guard steps.indices.contains(i) else { return }
            if how == .start { Sounds.beep(880, 0.15) } else { Sounds.bell() }
            Voice.shared.say(steps[i].text, .calm)
        case .ejercicio:
            // Drills are guided by their own sounds and a bell closes each one; a change's cue waits for the bell,
            // and the breathing has 5 quiet seconds for its cue.
            let steps = workout.steps
            if i == 0 {
                Sounds.beep(880, 0.15)
                if how == .start { sayEx(0) }
                return
            }
            guard steps[i].rest || i == steps.count - 1 else { return }
            let next = steps[i].rest ? i + 1 : i
            let seq = Voice.shared.seq
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                if Voice.shared.seq == seq && ex?.running == true { sayEx(next) }
            }
        }
    }

    private func second(_ k: RunKind, _ i: Int, _ remain: Int) {
        switch k {
        case .visualizacion:
            if remain == 10 { Sounds.softTone() }
        case .ejercicio:
            let steps = workout.steps
            guard GuidePlan(step: i, of: steps) == nil else { return }
            if remain > 0 && remain <= 3 { Sounds.beep(660, 0.08) }
            // The marcha has no change after it, so the first drill is announced a few seconds early.
            if remain == 6, let next = steps[safe: i + 1], !next.rest, !steps[i].rest { sayEx(i + 1) }
        }
    }

    private func sayEx(_ i: Int) {
        let w = workout
        Voice.shared.say(full: w.cueFull(i), short: w.cue(i), .energetic)
    }

    private func finish(_ k: RunKind) {
        let day = run(k)?.day ?? store.today
        set(k, nil)
        lastIdx[k] = 0
        lastRemain[k] = nil
        switch k {
        case .visualizacion:
            Sounds.bell()
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                Voice.shared.say(Self.visualizationDoneCue, .notice)
            }
        case .ejercicio:
            guideStop(from: nil)
            Sounds.beep(988, 0.25)
            Sounds.beep(1318, 0.35, delay: 0.26)
            Voice.shared.say(Exercise.doneCue, .notice)
        }
        changed()
        store.mark(k.letter, on: day)
        toast.show(k == .ejercicio ? String(localized: "Move done and checked off") : String(localized: "Imagine done and checked off"))
    }

    /// What the voice says when Imagine's minutes are over.
    static var visualizationDoneCue: String { String(localized: "Imagine is done.") }

    private func tick(_ k: RunKind) {
        guard let r = run(k), r.running else { return }
        let steps = steps(k)
        guard !steps.isEmpty else { reset(k); return }
        let el = r.elapsed(now)
        if el >= Self.total(steps) { finish(k); return }
        let idx = Self.stepAt(steps, el)
        if k == .ejercicio { guidePump(el) }
        if idx != lastIdx[k] {
            lastIdx[k] = idx
            lastRemain[k] = nil
            enter(k, idx, .auto)
        } else {
            let remain = Int((Self.stepStart(steps, idx) + steps[idx].secs - el).rounded(.up))
            if remain != lastRemain[k] {
                lastRemain[k] = remain
                second(k, idx, remain)
            }
        }
    }

    // MARK: The exercise guide

    private func guidePump(_ el: Double) {
        let from = guideFrom ?? el, to = el + Self.guideAhead
        let engine = ToneEngine.shared
        // Anything that went by while the app was asleep is dropped, not played in a burst.
        for e in workout.events where e.at >= from && e.at < to && e.at >= el - 0.5 {
            let delay = max(0, e.at - el)
            switch e.kind {
            case let .glide(move, dur, under):
                engine.glide(up: move == .up, duration: dur, level: under ? 0.09 : 0.2, delay: delay)
            case .tick:
                engine.tick(delay: delay)
            case .end:
                engine.drillBell(delay: delay)
            case let .word(w, tone):
                // Only Gemini's voice says the words; until they're made, the glides guide alone.
                if let clip = GeminiVoice.shared.clip(w, tone) { engine.clip(clip, delay: delay, group: .guide) }
            }
        }
        guideFrom = to
    }

    /// Pausing, skipping or starting again drops what was queued; the next pump starts from `from`.
    private func guideStop(from: Double?) {
        ToneEngine.shared.stop(.guide)
        guideFrom = from
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
            // The first time, iOS's question comes before leaving for the book.
            if notices.wants(.lectura) {
                let ok = await LocalNote.allowed()
                await notices.readPermission()
                if ok { await scheduleReadingNote(run) }
            }
            if let url = ReadApp(store.settings.readApp).url { await UIApplication.shared.open(url) }
        }
    }

    private func scheduleReadingNote(_ run: ReadingRun) async {
        let min = run.min
        await LocalNote.schedule(
            id: "lectura",
            at: Date(timeIntervalSince1970: run.start / 1000 + Double(min) * 60),
            title: String(localized: "Reading done"),
            body: String(localized: "You read for \(min) minutes. It checks itself off when you're back in Sunling.")
        )
        if reading?.start == run.start { reading?.sent = true; save() }
    }

    /// The "End of reading" switch changed while a reading runs.
    func readingNoteChanged() {
        guard let r = reading, r.left(.now) > 0 else { return }
        if notices.isOn(.lectura) { Task { await scheduleReadingNote(r) } } else { LocalNote.cancel("lectura") }
    }

    /// Cancel: the notice goes with it.
    func cancelReading() {
        LocalNote.cancel("lectura")
        reading = nil
        changed()
    }

    /// I'm done, or the time ran out.
    func finishReading() {
        guard let r = reading else { return }
        LocalNote.cancel("lectura")
        reading = nil
        changed()
        guard store.mark(.lectura, on: r.day) else { return }
        if store.routine.day(r.day).doneCount == 6 { Sounds.complete() } else { Sounds.check() }
        toast.show(String(localized: "Read checked off"))
    }

    // MARK: Keeping time

    /// When the app comes back: a new day drops yesterday's timers; a finished reading gets marked.
    func resume() {
        now = .now
        for k in RunKind.allCases { if let r = run(k), r.day != store.today { reset(k) } }
        if let r = reading, r.day != store.today { reading = nil; changed() }
        tick()
        syncTicker()
    }

    private func tick() {
        now = .now
        for k in RunKind.allCases { tick(k) }
        if let r = reading, r.left(now) == 0 { finishReading() }
    }

    private var anyRunning: Bool { ex?.running == true || vis?.running == true }

    private func syncTicker() {
        UIApplication.shared.isIdleTimerDisabled = anyRunning
        if !anyRunning {
            // The last sounds (the finish, a cue) keep their session a little longer.
            Task {
                try? await Task.sleep(for: .seconds(4))
                if !anyRunning { ToneEngine.shared.timerRunning = false }
            }
        }
        if anyRunning || reading != nil {
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
        for k in RunKind.allCases { prefs[k.storeKey] = run(k).flatMap(Self.json) }
        prefs["reading"] = reading.flatMap(Self.json)
    }

    private func restore() {
        let today = store.today
        for k in RunKind.allCases {
            let steps = steps(k), total = Self.total(steps)
            if let r: GuidedRun = Self.decode(prefs[k.storeKey]), r.day == today, !steps.isEmpty, r.elapsed(.now) < total + 600 {
                set(k, r)
                lastIdx[k] = Self.stepAt(steps, min(r.elapsed(.now), total - 0.001))
            }
        }
        if ex?.running == true || vis?.running == true { ToneEngine.shared.timerRunning = true }
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
    /// That app's own icon, in Assets. A paper book gets a plain gray tile, so the three line up in the menu.
    let icon: String

    init(_ key: String) {
        switch key {
        case "kindle": name = "Kindle"; url = URL(string: "kindle://"); icon = "KindleIcon"
        case "papel": name = String(localized: "Paper book"); url = nil; icon = "PaperIcon"
        default: name = String(localized: "Books"); url = URL(string: "ibooks://"); icon = "BooksIcon"
        }
    }
}
