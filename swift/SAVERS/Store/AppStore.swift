import Foundation
import Observation

/// Everything the app knows, kept on this iPhone. Local always wins the moment: nothing waits for the network.
@Observable
final class AppStore {
    private(set) var settings: AppSettings
    private(set) var days: [String: Day]
    private(set) var today: String
    /// Today is a day of rest and "Empezar mi amanecer" was tapped.
    var showOff = false
    private(set) var affReviewed: String
    /// "Want more time?" was answered: it's asked once.
    private(set) var moreTimeAsked: Bool
    /// The last changes from an AI, until undone or replaced by the next ones.
    private(set) var aiUndo: AIUndo?
    /// Set when saving to the phone fails, shown next to the greeting.
    private(set) var saveError: String?

    @ObservationIgnored private let persistence: Persistence
    @ObservationIgnored private let prefs: LocalPrefs
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var savedSettings: AppSettings
    /// Called after every save, so the cloud sends what changed.
    @ObservationIgnored var onSave: (() -> Void)?

    var routine: Routine { Routine(settings: settings, days: days, today: today) }

    init(persistence: Persistence = .standard, prefs: LocalPrefs = .standard) {
        self.persistence = persistence
        self.prefs = prefs
        let loaded = persistence.load()
        let s = loaded.settings ?? AppSettings()
        settings = s
        savedSettings = s
        days = loaded.days
        let now = DayKey.today
        today = now
        // The monthly review counts from the month after the app first sees this.
        let reviewed = prefs["affReviewed"] ?? DayKey.month(now)
        prefs["affReviewed"] = reviewed
        affReviewed = reviewed
        moreTimeAsked = prefs["moreTimeAsked"] != nil
        aiUndo = prefs["aiUndo"].flatMap { try? JSONDecoder().decode(AIUndo.self, from: Data($0.utf8)) }
        renameSaversBlock()
    }

    /// Saved at once, so the cloud and the Mac get "Amanecer" too.
    private func renameSaversBlock() {
        guard var sc = settings.schedule, sc.renameSaversBlock() else { return }
        changeSettings(delay: .zero) { $0.schedule = sc }
    }

    /// After midnight or when the app comes back.
    func refreshToday() {
        let now = DayKey.today
        guard now != today else { return }
        today = now
        showOff = false
    }

    // MARK: Changing a day

    private func change(_ ds: String, delay: Duration = .milliseconds(400), _ body: (inout Day) -> Void) {
        var d = days[ds] ?? Day(date: ds)
        body(&d)
        d.updatedAt = Date.now.iso
        days[ds] = d
        scheduleSave(after: delay)
    }

    /// Marks or unmarks a letter; returns whether it's marked now.
    @discardableResult
    func toggle(_ letter: Letter, on ds: String) -> Bool {
        let off = !routine.dayType(ds).hasSunrise
        var on = false
        change(ds, delay: .milliseconds(150)) { d in
            if off { d.extra = true }
            on = !d.isDone(letter)
            d.checks[letter.rawValue] = on
            var at = d.checkedAt ?? [:]
            at[letter.rawValue] = on ? Date.now.iso : nil
            d.checkedAt = at.isEmpty ? nil : at
        }
        return on
    }

    func setText(_ field: WritingField, _ text: String, on ds: String) {
        guard routine.day(ds)[field] != text else { return }
        change(ds) { $0[field] = text }
    }

    /// Marks a letter (a timer that ends, a reading that's over). False if it was already marked.
    @discardableResult
    func mark(_ letter: Letter, on ds: String) -> Bool {
        guard !routine.day(ds).isDone(letter) else { return false }
        toggle(letter, on: ds)
        return true
    }

    /// "Empezar mi amanecer" / "Registrar mi amanecer" on a day of rest.
    func doSaversAnyway(on ds: String) {
        if ds == today { showOff = true }
        change(ds, delay: .milliseconds(150)) { $0.extra = true }
    }

    // MARK: A date's own hours

    /// Back to what its weekday is: nothing to remember.
    func setDateType(_ ds: String, _ type: DayType) {
        let usual = routine.weekDayType(ds)
        change(ds, delay: .zero) { $0.type = type == usual ? nil : type.id }
    }

    /// Only what differs from the usual is kept, so later changes to the usual hours still reach this date.
    func setDateTime(_ ds: String, stepID: String, _ time: String) {
        let r = routine
        guard let st = r.step(r.dayType(ds), id: stepID) else { return }
        let usual = r.usualTime(st, weekday: DayKey.weekday(ds))
        change(ds, delay: .zero) { d in
            var times = d.times ?? [:]
            times[stepID] = TimeText.same(time, usual) ? nil : time
            d.times = times.isEmpty ? nil : times
        }
    }

    func setDateMinutes(_ ds: String, _ letter: Letter, _ minutes: Int) {
        let r = routine
        let usual = r.usualMinutes(r.scheduleKind(ds), letter, weekday: DayKey.weekday(ds))
        change(ds, delay: .zero) { d in
            var mins = d.mins ?? [:]
            mins[letter.rawValue] = minutes == usual ? nil : .number(Double(minutes))
            d.mins = mins.isEmpty ? nil : mins
        }
    }

    /// "Volver a lo de siempre"
    func resetDate(_ ds: String) {
        change(ds, delay: .zero) { d in
            d.times = nil
            d.mins = nil
        }
    }

    // MARK: Changing the settings

    private func changeSettings(delay: Duration = .milliseconds(400), _ body: (inout AppSettings) -> Void) {
        body(&settings)
        scheduleSave(after: delay)
    }


    func setReadApp(_ app: String) { changeSettings(delay: .zero) { $0.readApp = app } }

    func setAINotes(_ notes: String) { changeSettings { $0.aiNotes = notes } }

    func setBreatheNote(_ note: String) { changeSettings { $0.breatheNote = note } }

    /// "Want more time?": the steps get longer, unless their minutes were set by hand in Schedule.
    func setLength(_ length: SunriseLength) { changeSettings(delay: .zero) { $0.length = length } }

    /// "Want more time?", answered once: yes makes the sunrise the next length up.
    func answerMoreTime(_ yes: Bool) {
        if yes, let longer = settings.length?.longer { setLength(longer) }
        prefs["moreTimeAsked"] = "1"
        moreTimeAsked = true
    }

    /// The welcome's answers on a new install: one sunrise block at the hour you wake up, every day, its length,
    /// and three example phrases to make your own.
    func startFresh(wake: String, length: SunriseLength) {
        changeSettings(delay: .zero) { s in
            s.length = length
            s.schedule = .starter(wake: wake)
            if s.affirmations.filled.isEmpty { s.affirmations = AppSettings.exampleAffirmations }
        }
    }

    /// Empty ones are dropped; at least one (maybe empty) stays.
    func setAffirmations(_ items: [Item]) { changeSettings(delay: .zero) { $0.affirmations = Self.clean(items) } }

    func setVisualization(_ items: [Item], note: String) {
        changeSettings(delay: .zero) {
            $0.visualization = Visualization(items: Self.clean(items), note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private static func clean(_ items: [Item]) -> [Item] {
        let out = items.map { Item(label: $0.label.trimmingCharacters(in: .whitespacesAndNewlines), text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.label.isEmpty || !$0.text.isEmpty }
        return out.isEmpty ? [Item(text: "")] : out
    }

    /// Listo on Afirmaciones counts as this month's review, changed or not.
    func markAffirmationsReviewed() {
        let m = DayKey.month(today)
        prefs["affReviewed"] = m
        affReviewed = m
    }

    // MARK: The usual hours

    private func changeSchedule(_ body: (inout Schedule) -> Void) {
        changeSettings(delay: .zero) { s in
            var sc = s.schedule ?? .blank
            body(&sc)
            s.schedule = sc
        }
    }

    /// From today on: the days that passed keep what they were.
    func setWeekType(_ w: Int, _ type: DayType) {
        changeSchedule { $0.setWeek(w, to: type.id, today: today) }
    }

    // MARK: Kinds of day

    /// A new kind at the end of the list; returns its id. One that starts with the sunrise gets it at the
    /// hour of the first kind's.
    @discardableResult
    func addKind(named name: String, from start: Schedule.Start) -> String {
        let r = routine
        let first = r.firstSunrise
        let wake = r.settings.schedule?.type(first)?.sunriseBlockID.flatMap { r.step(first, id: $0)?.time } ?? "6:00"
        var id = ""
        changeSchedule { id = $0.addKind(named: name, from: start, wake: wake) }
        return id
    }

    func renameKind(_ kind: DayType, _ name: String) {
        changeSchedule { $0.renameKind(kind.id, to: name) }
    }

    /// Its weekdays and the dates to come changed to it become the first other kind with the sunrise. The days
    /// that passed stay as they were.
    func deleteKind(_ kind: DayType) {
        guard let fallback = routine.fallback(for: kind) else { return }
        let dates = routine.datesChanged(to: kind)
        changeSchedule { $0.deleteKind(kind.id, fallback: fallback.id, today: today) }
        for ds in dates { setDateType(ds, fallback) }
    }

    @discardableResult
    func addBlock(_ kind: DayType, group: TypeSchedule.Group, title: String, time: String) -> String? {
        var id: String?
        changeSchedule { id = $0.addBlock(kind.id, group: group, title: title, time: time) }
        return id
    }

    func renameBlock(_ kind: DayType, id: String, _ title: String) {
        changeSchedule { $0.renameBlock(kind.id, id: id, to: title) }
    }

    func removeBlock(_ kind: DayType, id: String) {
        changeSchedule { $0.removeBlock(kind.id, id: id) }
    }

    func moveStep(_ letter: Letter, in kind: DayType, to blockID: String) {
        changeSchedule { $0.moveStep(letter, in: kind.id, to: blockID) }
    }

    private func changeStep(_ kind: DayType, id: String, _ body: (inout Step) -> Void) {
        changeSchedule { sc in
            guard var t = sc.types?[kind.id] else { return }
            for g in TypeSchedule.Group.allCases {
                var list = t[g]
                guard let i = list.firstIndex(where: { $0.id == id }) else { continue }
                body(&list[i])
                t[g] = list
            }
            sc.types?[kind.id] = t
        }
    }

    /// For all the days of its kind (the weekdays' own hours go), or for one weekday only.
    /// A weekday's hour that's the same as the rest just follows them.
    func setStepTime(_ kind: DayType, id: String, weekday w: Int?, _ time: String) {
        changeStep(kind, id: id) { st in
            guard let w else {
                st.time = time
                st.times = nil
                return
            }
            var times = st.times ?? [:]
            if let k = Weekday.key(in: times, for: w) { times[k] = nil }
            if !TimeText.same(time, st.time) { times[Weekday.keys[w]] = time }
            st.times = times.isEmpty ? nil : times
        }
        if w == nil { changeSchedule { $0.types?[kind.id]?.place(id) } }
    }

    /// Silencio's or Lectura's minutes, like an hour: for all days, or one weekday (nil minutes: follow the rest).
    func setUsualMinutes(_ kind: DayType, _ letter: Letter, weekday w: Int?, _ minutes: Int?) {
        let key = letter.rawValue
        changeSchedule { sc in
            guard var t = sc.types?[kind.id] else { return }
            var days = t.minutesDays ?? [:]
            if let w {
                var own = days[key] ?? [:]
                if let k = Weekday.key(in: own, for: w) { own[k] = nil }
                let all = Routine.valid(t.minutes?[key]) ?? routine.defaultMinutes(letter)
                if let minutes, minutes != all { own[Weekday.keys[w]] = .number(Double(minutes)) }
                days[key] = own.isEmpty ? nil : own
            } else if let minutes {
                var all = t.minutes ?? [:]
                all[key] = .number(Double(minutes))
                t.minutes = all
                days[key] = nil
            }
            t.minutesDays = days.isEmpty ? nil : days
            sc.types?[kind.id] = t
        }
    }

    /// Minutes before "Dormido" for "Prepararte para dormir", every night.
    func setWindDown(_ minutes: Int) {
        changeSchedule { $0.windDown = minutes }
    }

    // MARK: Changes from an AI

    /// Applies the chosen changes at once and keeps how things were, for "Deshacer".
    func applyAI(_ changes: [AIChange]) {
        var s = settings
        var ds = days
        let dates = Set(changes.compactMap(\.date))
        for c in changes.sorted(by: { ($0.order, $0.id) < ($1.order, $1.id) }) {
            c.edit.apply(to: &s, days: &ds, today: today)
        }
        let now = Date.now.iso
        for d in dates { ds[d]?.updatedAt = now }
        let undo = AIUndo(before: settings, after: s,
                          datesBefore: Dictionary(uniqueKeysWithValues: dates.map { ($0, AIUndo.DateFields(days[$0])) }),
                          datesAfter: Dictionary(uniqueKeysWithValues: dates.map { ($0, AIUndo.DateFields(ds[$0])) }))
        settings = s
        days = ds
        flush()
        aiUndo = undo
        prefs["aiUndo"] = (try? JSONEncoder().encode(undo)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Back to just before the last changes from an AI. The notes for the AI stay as they are now.
    func undoAI() {
        guard let u = aiUndo else { return }
        var s = u.before
        s.aiNotes = settings.aiNotes
        settings = s
        for (ds, f) in u.datesBefore {
            change(ds, delay: .zero) { d in
                d.type = f.type
                d.times = f.times
                d.mins = f.mins
            }
        }
        aiUndo = nil
        prefs["aiUndo"] = nil
        flush()
    }

    // MARK: From the cloud

    /// The cloud's settings, if they're newer than this iPhone's (or always, the first time with an account).
    func applyCloudSettings(_ doc: [String: JSONValue], force: Bool) {
        guard let raw = doc["settings"], case .object = raw,
              let data = try? Persistence.encoder.encode(raw),
              let incoming = try? JSONDecoder().decode(AppSettings.self, from: data) else { return }
        let at = doc["updatedAt"]?.text ?? ""
        guard force || at > (prefs["settingsAt"] ?? "") else { return }
        settings = incoming
        savedSettings = incoming
        prefs["settingsAt"] = at
        prefs["settingsPushed"] = at
        flush()
        renameSaversBlock()
    }

    /// The cloud's days. The same version (often this iPhone's own write coming back) changes nothing; an older
    /// one never replaces a day with content, nor a change here that hasn't gone up yet.
    /// Returns the dates the cloud now has as they are here, with their `updatedAt`.
    func applyCloudDays(_ incoming: [String: JSONValue], unsent: Set<String>) -> [String: String] {
        var taken: [String: String] = [:]
        var changed = false
        for (ds, inc) in Persistence.days(from: incoming) {
            let at = inc.updatedAt ?? ""
            if let cur = days[ds] {
                let curAt = cur.updatedAt ?? ""
                // The cloud already has this version: nothing to change or send.
                if at == curAt { taken[ds] = at; continue }
                if at < curAt && (cur.hasContent || unsent.contains(ds)) { continue }
            }
            days[ds] = inc
            taken[ds] = at
            changed = true
        }
        if changed { flush() }
        return taken
    }

    // MARK: Saving

    private func scheduleSave(after delay: Duration) {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            flush()
        }
    }

    /// Writes now. Also when iOS is about to suspend the app, so the last keystrokes are never lost.
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        if settings != savedSettings {
            savedSettings = settings
            prefs["settingsAt"] = Date.now.iso
        }
        do {
            try persistence.save(settings: settings, days: days)
            saveError = nil
        } catch {
            saveError = String(localized: "Couldn't save")
        }
        onSave?()
    }
}
