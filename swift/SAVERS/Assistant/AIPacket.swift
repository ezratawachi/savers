import Foundation

/// What "Send to an AI" sends: the instructions, the notes, the question, each day as it is, the last
/// weeks' marks and the configuration the AI can change. Never what was written in Write.
enum AIPacket {
    static let weeks = 8

    static func text(_ r: Routine, question: String) -> String {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = r.settings.aiNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = []
        parts.append(String(localized: "# My sunrise in Sunling\n\nToday is \(DayKey.long(r.today).inSentence) (\(r.today)). Here's everything from Sunling, my app for starting the day, so you can help me."))
        parts.append(String(localized: "## What I want") + "\n\n" + (q.isEmpty ? String(localized: "I don't know yet. Ask me what I want to talk about.") : q))
        parts.append(String(localized: "## My notes (what the app doesn't know)") + "\n\n" + (notes.isEmpty ? String(localized: "No notes.") : notes))
        parts.append(howToWork)
        parts.append(howItWorks)
        parts.append(String(localized: "## What each day looks like (worked out by the app, read only)") + "\n\n" + r.aiWeek())
        let dates = r.aiDates()
        if !dates.isEmpty { parts.append(String(localized: "## Dates with changes (read only)") + "\n\n" + dates) }
        parts.append(String(localized: "## How it's gone (last \(weeks) weeks, read only)") + "\n\n" + r.aiRecord(weeks: weeks))
        parts.append(String(localized: "## My configuration (this is what can be changed)") + "\n\n```json\n" + r.aiConfig().rendered() + "\n```")
        parts.append(changeBlock(r))
        return parts.joined(separator: "\n\n") + "\n"
    }

    private static var howToWork: String {
        String(localized: """
        ## How to work with me

        - Talk first: understand what I'm asking, ask me what you don't know and suggest ideas. I don't always want to change something; sometimes I want to think or discuss.
        - Respect my notes: what they say doesn't move, doesn't move.
        - Give me the change block only when I accept a proposal or ask you for the changes. Not before.
        - Before suggesting a time, check that the block's steps end before the next block.
        """)
    }

    /// Each language names its own configuration words (`AIWord`).
    private static var howItWorks: String {
        String(localized: """
        ## How the app works

        - My sunrise is six short steps each morning, to start the day with myself before the world. It's always all six: when time is short, they get shorter, they don't get dropped.
          - Breathe: a few minutes still, to breathe, meditate or pray.
          - Affirm: out loud, a few phrases I believe about who I choose to be. Nothing over the top like "I'm amazing": for someone who doesn't believe it, it makes things worse.
          - Imagine: today's most important thing, the likely obstacle and what I'll do if it comes up ("if X happens, I'll do Y"). The path, not just the goal reached.
          - Move: a few minutes of movement at home, or the gym.
          - Read: a few pages of something that helps me grow.
          - Write: give thanks for something specific and jot down an idea from what I read.
        - It's a method of its own, with these names. Even if it looks like others you know, don't call it by another name or use their acronyms.
        - Rest counts too: a rest day doesn't break my sunrises in a row.
        - Each weekday is Normal, Gym or Rest. Saturday is Shabbat and doesn't change.
        - Normal and Gym each have their own schedule of blocks with a time (for example Get up, Sunrise, Shower, Asleep). Some blocks hold steps, in order.
        - Each step's time is its block's time plus the minutes of the steps before it. To move a step, its block moves or minutes change.
        - Only Breathe and Read have minutes that can be changed: from 1 to 60, or 75, 90, 105 or 120. The other steps' minutes come from their content (Affirm about 25 seconds per phrase, Imagine up to a minute per question, Write 1 or 2, Move 2 or 8 at home or however long the gym lasts). The schedule below has the real ones.
        - The bedtime block is in "The night before": it's when I go to sleep the night before that day. "windDown" is how many minutes before bedtime the reminder to get ready arrives: from 15 to 90, in steps of 5, the same every night.
        - A time or some minutes can be different on one weekday ("hoursByDay", "minutesByDay") or on one date ("dates", from today up to a year ahead).
        - Blocks can't be added, removed or renamed, and steps can't move from one block to another. If that would suit me, tell me in the conversation, not in the change block.
        """)
    }

    private static func changeBlock(_ r: Routine) -> String {
        let block = r.aiBlocks(r.firstSunrise).first { !$0.step.letterKeys.isEmpty }?.name ?? String(localized: "Sunrise")
        return String(localized: """
        ## The change block

        When I ask you to, at the end of your reply put a code block marked `sunling` with a JSON that has **only what changes**, in the same shape as my configuration. Whatever you leave out stays the same.

        - Morning times are written "5:20"; afternoon and evening ones with pm: "8:50 pm".
        - To bring a weekday's or a date's time or minutes back to the usual, set them to null. To remove all of a date's changes: "YYYY-MM-DD": null.
        - The affirmations and the Imagine questions go complete and in their final order, even if only one changes.
        - Use the block names exactly as they are in my configuration.

        Example of the shape (not a proposal):

        ```sunling
        {
          "normal": {"hours": {"\(block)": "5:45"}, "minutes": {"read": 15}},
          "week": {"thursday": "gym"},
          "dates": {"YYYY-MM-DD": {"type": "rest"}}
        }
        ```

        I copy your reply and paste it into the app, which shows me each change before applying it.
        """)
    }
}

extension Routine {
    // MARK: The configuration

    func aiConfig() -> OrderedJSON {
        var top: [(String, OrderedJSON)] = [
            (AIWord.readOn, .string(AIWord.readApp(settings.readApp))),
            (AIWord.affirmations, .array(settings.affirmations.filled.map(Self.aiItem))),
            (AIWord.visualization, .object([
                (AIWord.questions, .array(settings.visualization.items.filled.map(Self.aiItem))),
                (AIWord.note, .string(settings.visualization.note)),
            ])),
            (AIWord.week, .object((0...5).map { (AIWord.weekday($0), .string(weekType($0).name)) })),
            (AIWord.windDown, .number(windDown)),
        ]
        for kind in types where kind.hasSunrise && settings.schedule?.type(kind) != nil {
            top.append((AIText.key(kind.name), aiKind(kind)))
        }
        top.append((AIWord.dates, .object(aiDateKeys().map { ($0, aiDate($0)) })))
        return .object(top)
    }

    private static func aiItem(_ i: Item) -> OrderedJSON {
        i.label.isEmpty ? .string(i.text) : .object([(AIWord.title, .string(i.label)), (AIWord.text, .string(i.text))])
    }

    private func aiKind(_ kind: DayType) -> OrderedJSON {
        let blocks = aiBlocks(kind)
        var out: [(String, OrderedJSON)] = [(AIWord.hours, .object(blocks.map { ($0.name, .string($0.step.time ?? "")) }))]
        let perDay: [(String, OrderedJSON)] = blocks.compactMap { b in
            let own = (0...5).compactMap { w in ownTime(b.step, weekday: w).map { (AIWord.weekday(w), OrderedJSON.string($0)) } }
            return own.isEmpty ? nil : (b.name, .object(own))
        }
        if !perDay.isEmpty { out.append((AIWord.hoursByDay, .object(perDay))) }
        let letters = [Letter.silencio, .lectura]
        out.append((AIWord.minutes, .object(letters.map { ($0.aiKey, .number(usualMinutes(kind, $0, weekday: nil))) })))
        let minsPerDay: [(String, OrderedJSON)] = letters.compactMap { l in
            let own = (0...5).compactMap { w in ownMinutes(kind, l, weekday: w).map { (AIWord.weekday(w), OrderedJSON.number($0)) } }
            return own.isEmpty ? nil : (l.aiKey, .object(own))
        }
        if !minsPerDay.isEmpty { out.append((AIWord.minutesByDay, .object(minsPerDay))) }
        return .object(out)
    }

    /// Dates from today on with a kind, hours or minutes of their own.
    func aiDateKeys() -> [String] {
        days.keys.filter { ds in
            guard ds >= today, let d = days[ds] else { return false }
            return d.type != nil || dateEdited(ds)
        }.sorted()
    }

    private func aiDate(_ ds: String) -> OrderedJSON {
        let d = day(ds)
        var out: [(String, OrderedJSON)] = []
        if d.type != nil { out.append((AIWord.type, .string(dayType(ds).name))) }
        if isScheduled(ds) {
            let kind = scheduleKind(ds)
            let hours: [(String, OrderedJSON)] = aiBlocks(kind).compactMap { b in
                guard let id = b.step.id, let t = d.times?[id], !t.isEmpty else { return nil }
                return (b.name, .string(t))
            }
            if !hours.isEmpty { out.append((AIWord.hours, .object(hours))) }
            let mins: [(String, OrderedJSON)] = [Letter.silencio, .lectura].compactMap { l in
                Self.valid(d.mins?[l.rawValue]).map { (l.aiKey, .number($0)) }
            }
            if !mins.isEmpty { out.append((AIWord.minutes, .object(mins))) }
        }
        return .object(out)
    }

    // MARK: Each day as text

    /// The week, weekdays that look the same together: "Monday, Tuesday and Thursday (Normal)" and their hours.
    func aiWeek() -> String {
        var order: [String] = []
        var who: [String: [Int]] = [:]
        for w in 0...6 {
            let type = weekType(w)
            let body = type.hasSunrise
                ? aiTimeline(type, time: { usualTime($0, weekday: w) }, minutes: { letterMinutes($0, type, weekday: w) })
                : ""
            let key = type.name + "\n" + body
            if who[key] == nil { order.append(key) }
            who[key, default: []].append(w)
        }
        return order.map { key in
            let ws = who[key] ?? []
            let list = AppLanguage.list(ws.map { Weekday.names[$0] })
            let parts = key.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            let body = parts.count > 1 ? String(parts[1]) : ""
            return "**\(list.capitalizedFirst) (\(parts.first ?? ""))**" + (body.isEmpty ? "" : "\n" + body)
        }.joined(separator: "\n\n")
    }

    /// Each date with changes of its own, with its hours that day.
    func aiDates() -> String {
        aiDateKeys().map { ds in
            let type = dayType(ds)
            let head = "**\(DayKey.long(ds)) (\(ds), \(type.name))**"
            guard isScheduled(ds) else { return head }
            let kind = scheduleKind(ds)
            return head + "\n" + aiTimeline(kind, time: { time(of: $0, on: ds) }, minutes: { letterMinutes($0, kind, on: ds) })
        }.joined(separator: "\n\n")
    }

    /// "The night before / 10:25 pm Asleep", "Morning / 5:55 Sunrise / 5:55 Breathe · 10 min", "Later / …".
    private func aiTimeline(_ kind: DayType, time: (Step) -> String, minutes: (Letter) -> Int) -> String {
        guard let t = settings.schedule?.type(kind) else { return "" }
        let bedID = bedStep(kind)?.id
        var seen: Set<Letter> = []
        var lines: [String] = []
        for g in TypeSchedule.Group.allCases where !t[g].isEmpty {
            lines.append(g.title ?? String(localized: "Morning"))
            for st in t[g] {
                let at = time(st)
                let title = st.title ?? st.label
                var line = "- \(at.isEmpty ? String(localized: "no time") : at) \(title)"
                if let detail = st.detail, !detail.isEmpty { line += " (\(detail))" }
                if st.id == bedID, let m = TimeText.minutes(at) {
                    line += " · " + String(localized: "wind down from \(TimeText.label((m - windDown + 1440) % 1440))")
                }
                let keys = st.letterKeys.filter { seen.insert($0).inserted }
                if keys.count == 1, keys[0].name == title {
                    let m = minutes(keys[0])
                    lines.append(line + (m > 0 ? " · " + String(localized: "\(m) min") : ""))
                    continue
                }
                lines.append(line)
                var start = TimeText.minutes(at)
                for k in keys {
                    let m = minutes(k)
                    lines.append("  - " + [start.map(TimeText.label), k.name, m > 0 ? String(localized: "\(m) min") : nil].compactMap { $0 }.joined(separator: " "))
                    if let s = start { start = s + m }
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: The record

    /// Totals per step, then each day with a sunrise: what was marked and when. From the first day with a
    /// mark, so the weeks before the app don't read as days missed.
    func aiRecord(weeks: Int) -> String {
        let first = days.filter { $0.value.doneCount > 0 }.keys.min() ?? today
        let dates = (0..<(weeks * 7)).reversed().map { DayKey.adding(-$0, to: today) }.filter { $0 >= first }
        var lines: [String] = []
        var count = 0
        var complete = 0
        var perLetter: [Letter: Int] = [:]
        var anyHour = false
        for ds in dates {
            let type = dayType(ds)
            let d = day(ds)
            guard type.hasSunrise || d.extra || d.doneCount > 0 else { continue }
            count += 1
            if d.doneCount == 6 { complete += 1 }
            for l in Letter.allCases where d.isDone(l) { perLetter[l, default: 0] += 1 }
            var line = "- \(DayKey.short(ds)) · \(type.name)" + (type.hasSunrise ? "" : " (" + String(localized: "did it anyway") + ")")
            let done = Letter.allCases.filter(d.isDone)
            let hours = done.map { l in (l, aiHour(d.checkedAt?[l.rawValue], ds: ds)) }
            if hours.contains(where: { $0.1 != nil }) {
                anyHour = true
                line += " · " + hours.map { [$0.0.name, $0.1].compactMap { $0 }.joined(separator: " ") }.joined(separator: ", ")
            } else if done.count == 6 {
                line += " · " + String(localized: "all 6")
            } else if !done.isEmpty {
                line += " · " + done.map(\.name).joined(separator: ", ")
            }
            let missing = Letter.allCases.filter { !d.isDone($0) }.map(\.name).joined(separator: ", ")
            if done.isEmpty {
                line += " · " + (ds == today ? String(localized: "today, nothing checked yet") : String(localized: "nothing checked"))
            } else if !missing.isEmpty {
                line += " · " + (ds == today ? String(localized: "today, still without: \(missing)") : String(localized: "missed: \(missing)"))
            }
            lines.append(line)
        }
        guard count > 0 else { return String(localized: "No days logged yet.") }
        let totals = Letter.allCases.map { "\($0.name) \(perLetter[$0, default: 0])" }.joined(separator: ", ")
        let head = [
            String(localized: "Days with a sunrise: \(count). Complete: \(complete). By step: \(totals)."),
            anyHour
                ? String(localized: "The time next to each step is when I checked it off in the app (it can be after doing it).")
                : String(localized: "The app didn't save yet what time I check off each step."),
            String(localized: "Saturdays and rest days only show up if I did my sunrise anyway."),
        ].joined(separator: " ")
        return head + "\n\n" + lines.joined(separator: "\n")
    }

    /// "6:02", or "11:40 pm on Mon, Sep 28" when it was marked on another day.
    private func aiHour(_ iso: String?, ds: String) -> String? {
        guard let date = Date(iso: iso) else { return nil }
        let p = DayKey.calendar.dateComponents([.hour, .minute], from: date)
        let label = TimeText.label((p.hour ?? 0) * 60 + (p.minute ?? 0))
        let on = DayKey.of(date)
        return on == ds ? label : String(localized: "\(label) on \(DayKey.short(on))")
    }
}
