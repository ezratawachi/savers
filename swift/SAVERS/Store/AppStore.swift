import Foundation
import Observation

/// Everything the app knows, kept on this iPhone. Local always wins the moment: nothing waits for the network.
@Observable
final class AppStore {
    private(set) var settings: AppSettings
    private(set) var days: [String: Day]
    private(set) var today: String
    /// Today is a day without SAVERS and "Hacer mis SAVERS hoy" was tapped.
    var showOff = false
    private(set) var affReviewed: String
    private(set) var lastExport: Date?
    private(set) var since: Date
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
        lastExport = Date(iso: prefs["lastExport"])
        let first = Date(iso: prefs["since"]) ?? .now
        prefs["since"] = first.iso
        since = first
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
        let off = routine.dayType(ds) == .off
        var on = false
        change(ds, delay: .milliseconds(150)) { d in
            if off { d.extra = true }
            on = !d.isDone(letter)
            d.checks[letter.rawValue] = on
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

    /// "Hacer mis SAVERS hoy" / "Registrar mis SAVERS" on a day without them.
    func doSaversAnyway(on ds: String) {
        if ds == today { showOff = true }
        change(ds, delay: .milliseconds(150)) { $0.extra = true }
    }

    // MARK: A date's own hours

    /// Back to what its weekday is: nothing to remember.
    func setDateType(_ ds: String, _ type: DayType) {
        let usual = routine.weekDayType(ds)
        change(ds, delay: .zero) { $0.type = type == usual ? nil : type.rawValue }
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

    func setName(_ name: String) { changeSettings { $0.name = name } }

    func setReadApp(_ app: String) { changeSettings(delay: .zero) { $0.readApp = app } }

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

    func setWeekType(_ w: Int, _ type: DayType) {
        changeSchedule { $0.week[String(w)] = type.rawValue }
    }

    private func changeStep(_ kind: DayType, id: String, _ body: (inout Step) -> Void) {
        changeSchedule { sc in
            guard var t = sc.types?[kind.rawValue] else { return }
            for g in TypeSchedule.Group.allCases {
                var list = t[g]
                guard let i = list.firstIndex(where: { $0.id == id }) else { continue }
                body(&list[i])
                t[g] = list
            }
            sc.types?[kind.rawValue] = t
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
    }

    /// Silencio's or Lectura's minutes, like an hour: for all days, or one weekday (nil minutes: follow the rest).
    func setUsualMinutes(_ kind: DayType, _ letter: Letter, weekday w: Int?, _ minutes: Int?) {
        let key = letter.rawValue
        changeSchedule { sc in
            guard var t = sc.types?[kind.rawValue] else { return }
            var days = t.minutesDays ?? [:]
            if let w {
                var own = days[key] ?? [:]
                if let k = Weekday.key(in: own, for: w) { own[k] = nil }
                let all = Routine.valid(t.minutes?[key]) ?? letter.usualMinutes
                if let minutes, minutes != all { own[Weekday.keys[w]] = .number(Double(minutes)) }
                days[key] = own.isEmpty ? nil : own
            } else if let minutes {
                var all = t.minutes ?? [:]
                all[key] = .number(Double(minutes))
                t.minutes = all
                days[key] = nil
            }
            t.minutesDays = days.isEmpty ? nil : days
            sc.types?[kind.rawValue] = t
        }
    }

    /// Minutes before "Dormido" for "Prepararte para dormir", every night.
    func setWindDown(_ minutes: Int) {
        changeSchedule { $0.windDown = minutes }
    }

    // MARK: Import

    /// Replaces the parts of the settings the copy brings; days are added, the newest `updatedAt` wins.
    func apply(_ backup: Backup) {
        var s = settings
        let incoming = backup.settings
        for part in backup.parts {
            switch part {
            case .name: s.name = incoming.name
            case .affirmations: s.affirmations = incoming.affirmations
            case .visualization: s.visualization = incoming.visualization
            case .schedule: s.schedule = incoming.schedule
            }
        }
        settings = s
        for (ds, inc) in backup.days {
            if let cur = days[ds], cur.hasContent, (inc.updatedAt ?? "") < (cur.updatedAt ?? "") { continue }
            days[ds] = inc
        }
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
            saveError = "No se pudo guardar"
        }
        onSave?()
    }

    // MARK: Backup reminder

    /// Days since the last copy, or since the app started if there never was one.
    var backupAge: Int { Int(Date.now.timeIntervalSince(lastExport ?? since) / 86_400) }

    /// Only without the cloud: with it on, the cloud keeps the copy.
    func backupOverdue(cloudLinked: Bool) -> Bool { !cloudLinked && backupAge > 14 }

    func markBackedUp() {
        let now = Date.now
        prefs["lastExport"] = now.iso
        lastExport = now
    }

    /// `savers-copia-AAAA-MM-DD.json`: everything, plus the routine day by day for an AI to read.
    func backupData() -> Data? {
        flush()
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let s = try? JSONDecoder().decode(JSONValue.self, from: Persistence.encoder.encode(settings)),
              let d = try? JSONDecoder().decode(JSONValue.self, from: Persistence.encoder.encode(days)) else { return nil }
        let root: [String: JSONValue] = [
            "app": .string("savers"), "version": .number(2), "exportedAt": .string(Date.now.iso),
            "paraLaIA": .string(Backup.summaryNote), "resumen": .object(routine.weekSummary()),
            "settings": s, "days": d,
        ]
        return try? enc.encode(root)
    }
}
