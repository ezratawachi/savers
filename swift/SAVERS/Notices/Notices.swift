import Foundation
import Observation
import UIKit
import UserNotifications

/// The four notices, each with its own switch in Settings › Notifications.
enum NoteKind: String, CaseIterable, Identifiable {
    case lectura, leer, dormir, revision

    var id: String { rawValue }

    var name: String {
        switch self {
        case .lectura: String(localized: "End of reading")
        case .leer: String(localized: "Time to read")
        case .dormir: String(localized: "Wind down for bed")
        case .revision: String(localized: "Monthly review")
        }
    }

    func about(_ r: Routine) -> String {
        switch self {
        case .lectura: String(localized: "When your minutes are up, even if Sunling is closed.")
        case .leer: String(localized: "On gym days, if you haven't read yet.")
        case .dormir: String(localized: "\(r.windDown) minutes before bedtime, Sunday to Thursday. You change it in Schedule.")
        case .revision: String(localized: "Affirm and Imagine, the first Sunday at 11:00 am.")
        }
    }
}

/// One notice to schedule.
struct PlannedNote: Equatable {
    var id: String
    var at: Date
    var title: String
    var body: String
}

/// What the iPhone lets SAVERS do, the switches (`savers:avisos`, only on this iPhone), and the notices
/// planned two weeks ahead. Each open and each change plans them again from the schedule, so a changed hour
/// moves its notice. Nothing in the morning, and nothing from Friday afternoon until Shabbat ends.
@Observable
final class Notices {
    enum Permission { case notAsked, allowed, blocked }

    private(set) var permission = Permission.notAsked
    private(set) var wanted: [String: Bool]
    /// The switch whose question iOS is showing.
    private(set) var busy: NoteKind?
    /// The last notice tapped, until Hoy opens what it's about.
    var tapped: String?

    @ObservationIgnored private let store: AppStore
    @ObservationIgnored private let prefs: LocalPrefs
    @ObservationIgnored private var planTask: Task<Void, Never>?
    @ObservationIgnored private let delegate = NoteDelegate()

    static let planDays = 14

    init(store: AppStore, prefs: LocalPrefs = .standard) {
        self.store = store
        self.prefs = prefs
        wanted = prefs["avisos"].flatMap { try? JSONDecoder().decode([String: Bool].self, from: Data($0.utf8)) } ?? [:]
        // Set before the app finishes launching, so a tap that opens it isn't lost.
        UNUserNotificationCenter.current().delegate = delegate
        delegate.onTap = { [weak self] id in self?.tapped = id }
    }

    // MARK: Switches

    /// All on until you turn them off.
    func wants(_ kind: NoteKind) -> Bool { wanted[kind.rawValue] ?? true }

    func isOn(_ kind: NoteKind) -> Bool { wants(kind) && permission == .allowed }

    var anyOn: Bool { NoteKind.allCases.contains(where: isOn) }

    /// Turning one on asks iOS the first time; turning it off is only this switch.
    func turn(_ kind: NoteKind, on: Bool) async {
        if on {
            busy = kind
            let ok = await LocalNote.allowed()
            await readPermission()
            busy = nil
            guard ok else { return }
        }
        wanted[kind.rawValue] = on
        prefs["avisos"] = (try? JSONEncoder().encode(wanted)).flatMap { String(data: $0, encoding: .utf8) }
        planSoon()
    }

    func readPermission() async {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: permission = .allowed
        case .notDetermined: permission = .notAsked
        default: permission = .blocked
        }
    }

    func test() async {
        await LocalNote.schedule(id: "prueba", at: .now, title: String(localized: "Notifications work"), body: String(localized: "This is how Sunling's notifications reach you."))
    }

    // MARK: Planning

    /// A beat after a change, so a run of edits plans once.
    func planSoon() {
        #if DEBUG
        // A scenario's made-up days never touch the real notices.
        if Scenario.current != nil { return }
        #endif
        planTask?.cancel()
        planTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await plan()
        }
    }

    func plan() async {
        await readPermission()
        let want = permission == .allowed ? notes(store.routine, reviewed: store.affReviewed, now: .now) : []
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let wantIDs = Set(want.map(\.id))
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { Self.isPlanned($0) && !wantIDs.contains($0) })
        for n in want where !Self.same(n, pending.first { $0.identifier == n.id }) {
            await LocalNote.schedule(id: n.id, at: n.at, title: n.title, body: n.body)
        }
    }

    /// The ones this planner owns; "lectura" and "prueba" come and go on their own.
    private static func isPlanned(_ id: String) -> Bool { id == "revision" || id.hasPrefix("dormir-") || id.hasPrefix("leer-") }

    private static func same(_ n: PlannedNote, _ r: UNNotificationRequest?) -> Bool {
        guard let r, let t = r.trigger as? UNCalendarNotificationTrigger, let at = DayKey.calendar.date(from: t.dateComponents) else { return false }
        return r.content.title == n.title && r.content.body == n.body && abs(at.timeIntervalSince(n.at)) < 1
    }

    /// What should be waiting on the iPhone right now.
    func notes(_ r: Routine, reviewed: String, now: Date) -> [PlannedNote] {
        var out: [PlannedNote] = []
        func add(_ n: PlannedNote?) {
            if let n, n.at > now, !Self.shabbatQuiet(n.at) { out.append(n) }
        }
        let today = DayKey.of(now)
        for i in 0...Self.planDays {
            let ds = DayKey.adding(i, to: today)
            if wants(.dormir) { add(Self.bedNote(r, ds)) }
            if wants(.leer) { add(Self.readNote(r, ds)) }
        }
        if wants(.revision) { add(Self.reviewNote(r, reviewed: reviewed, now: now)) }
        return out
    }

    /// Friday from 3:00 pm and all of Saturday.
    static func shabbatQuiet(_ at: Date) -> Bool {
        let c = DayKey.calendar.dateComponents([.weekday, .hour], from: at)
        return c.weekday == 7 || (c.weekday == 6 && (c.hour ?? 0) >= 15)
    }

    private static func at(_ ds: String, minute: Int) -> Date {
        DayKey.calendar.date(byAdding: .minute, value: minute, to: DayKey.date(ds)) ?? DayKey.date(ds)
    }

    /// The night before a sunrise day, `windDown` minutes before its "Dormido".
    static func bedNote(_ r: Routine, _ ds: String) -> PlannedNote? {
        guard r.isScheduled(ds) else { return nil }
        let kind = r.scheduleKind(ds)
        guard let steps = r.settings.schedule?.type(kind)?[.steps], let bedStep = r.bedStep(kind),
              let bed = TimeText.minutes(r.time(of: bedStep, on: ds)) else { return nil }
        let wakeStep = steps.first { s in ["te paras", "despiert", "get up", "wake"].contains { s.title?.localizedCaseInsensitiveContains($0) == true } } ?? steps.first
        let wake = wakeStep.flatMap { TimeText.minutes(r.time(of: $0, on: ds)) }
        // "10:15 pm" is the night before; "12:10 am" would already be the day itself.
        let night0 = bed >= 12 * 60 ? DayKey.adding(-1, to: ds) : ds
        var body = String(localized: "Asleep at \(TimeText.label(bed)).")
        if let wake {
            let up = TimeText.label(wake)
            body += " " + (kind == .gym ? String(localized: "Tomorrow is gym: you get up at \(up).") : String(localized: "Tomorrow you get up at \(up)."))
        }
        return PlannedNote(id: "dormir-" + ds, at: at(night0, minute: bed - r.windDown), title: String(localized: "Time to wind down for bed"), body: body)
    }

    /// A Read that's "Later" that day (the gym days), while it isn't marked.
    static func readNote(_ r: Routine, _ ds: String) -> PlannedNote? {
        guard r.isScheduled(ds), !r.day(ds).isDone(.lectura) else { return nil }
        let kind = r.scheduleKind(ds)
        guard let min = TimeText.minutes(r.laterTime(kind, .lectura, on: ds)) else { return nil }
        let n = r.letterMinutes(.lectura, kind, on: ds)
        return PlannedNote(id: "leer-" + ds, at: at(ds, minute: min), title: String(localized: "Time to read"), body: String(localized: "Your \(n) minutes of reading for today."))
    }

    /// The first Sunday of the month at 11:00; this month's only while it's still ahead and not done.
    static func reviewNote(_ r: Routine, reviewed: String, now: Date) -> PlannedNote? {
        guard !r.settings.affirmations.filled.isEmpty || !r.settings.visualization.items.filled.isEmpty else { return nil }
        let cal = DayKey.calendar
        func firstSunday(_ monthsAhead: Int) -> Date {
            let start = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
            let first = cal.date(byAdding: .month, value: monthsAhead, to: start) ?? start
            let w = cal.component(.weekday, from: first) - 1
            let sunday = cal.date(byAdding: .day, value: (7 - w) % 7, to: first) ?? first
            return cal.date(byAdding: .hour, value: 11, to: sunday) ?? sunday
        }
        var at = firstSunday(0)
        if reviewed == DayKey.month(DayKey.of(now)) || at <= now { at = firstSunday(1) }
        return PlannedNote(id: "revision", at: at, title: String(localized: "Monthly review"), body: String(localized: "Do your affirmations and your Imagine questions still feel like yours?"))
    }
}

/// iOS's side: a notice shows even with Sunling open, and a tap says which one it was.
/// Kept apart because iOS calls it off the main thread.
nonisolated final class NoteDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    @MainActor var onTap: ((String) -> Void)?

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // With Sunling open, the reading marks itself with its own sound; a second bell would be too much.
        notification.request.identifier == "lectura" ? [] : [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let id = response.notification.request.identifier
        await MainActor.run { onTap?(id) }
    }
}
