import SwiftUI

/// One month on the night: its name as the title, how many mornings were complete, then each day as a
/// little sun on its own horizon. The first time a month is shown in a session its suns rise in a wave.
struct MonthGrid: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let month: MonthIndex
    /// The month in view: the one whose suns rise.
    let isShown: Bool
    let onOpen: (String) -> Void

    @State private var risen: Bool

    init(month: MonthIndex, isShown: Bool, onOpen: @escaping (String) -> Void) {
        self.month = month
        self.isShown = isShown
        self.onOpen = onOpen
        _risen = State(initialValue: Self.seen.contains(month))
    }

    /// The months whose suns already rose since the app opened.
    @MainActor private static var seen: Set<MonthIndex> = []

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let r = store.routine
        let today = store.today
        let dates = month.dates
        let lead = DayKey.weekday(month.first)
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                if month.year != MonthIndex(of: today).year {
                    Text(String(month.year))
                        .font(.reading(13, relativeTo: .footnote))
                        .tracking(1)
                        .foregroundStyle(.muted)
                }
                Text(DayKey.monthOnly(month))
                    .font(.display(44, relativeTo: .largeTitle, weight: .heavy))
                    .tracking(-1)
                    .foregroundStyle(.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel(DayKey.monthName(month))
                Text(countLine(r, dates, today: today))
                    .font(.reading(16, relativeTo: .subheadline))
                    .foregroundStyle(.muted)
            }
            .padding(.trailing, 100)
            LazyVGrid(columns: Self.columns, spacing: 10) {
                // Ids of their own: in one grid, the heads, the blanks and the days must never share one.
                ForEach(Weekday.letters.indices.map { "head-\($0)" }, id: \.self) { key in
                    Text(Weekday.letters[Int(key.dropFirst(5)) ?? 0])
                        .font(.reading(13, relativeTo: .caption).bold())
                        .foregroundStyle(.muted)
                        .accessibilityHidden(true)
                }
                ForEach((0..<lead).map { "blank-\($0)" }, id: \.self) { _ in
                    Color.clear.frame(height: 1)
                }
                ForEach(Array(dates.enumerated()), id: \.element) { i, ds in
                    DayCell(ds: ds, routine: r, today: today, risen: risen) { onOpen(ds) }
                        .animation(rise(delay: Double(lead + i) * 0.012), value: risen)
                }
            }
        }
        .onChange(of: isShown, initial: true) { _, shown in
            guard shown, !risen else { return }
            Self.seen.insert(month)
            risen = true
        }
    }

    /// The wave: each day a beat after the one before; nothing moves with Reduce Motion.
    private func rise(delay: Double) -> Animation? {
        reduceMotion ? nil : Motion.sun.delay(delay)
    }

    private func countLine(_ r: Routine, _ dates: [String], today: String) -> String {
        let scheduled = dates.filter { $0 <= today && r.isScheduled($0) }
        let complete = scheduled.count { r.day($0).doneCount == 6 }
        if !scheduled.isEmpty {
            return scheduled.count == 1 ? String(localized: "\(complete) of 1 morning complete") : String(localized: "\(complete) of \(scheduled.count) mornings complete")
        }
        return month.first > today ? String(localized: "Still to come") : String(localized: "No mornings yet")
    }
}

/// A day: its number, and its sun risen by its letters (a whole sun on a golden line when complete).
/// Only days lived have a horizon; days to come are just their number, faded, with a sky dot if they
/// were changed for themselves. Today's number in sky. Shabbat and a day off with nothing: the line.
private struct DayCell: View {
    let ds: String
    let routine: Routine
    let today: String
    let risen: Bool
    let action: () -> Void

    var body: some View {
        let type = routine.dayType(ds)
        let d = routine.day(ds)
        let n = d.doneCount
        let future = ds > today
        let off = type == .shabbat || (type == .off && !d.hasContent)
        let planned = future && type != .shabbat && (d.type != nil || d.times != nil || d.mins != nil)
        let isToday = ds == today

        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(DayKey.calendar.component(.day, from: DayKey.date(ds)))")
                    .font(.reading(14, relativeTo: .footnote).weight(isToday || n == 6 ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(isToday ? Color.sky : off || future ? Color.muted : Color.ink)
                DaySun(rise: risen && !off ? DaySun.rise(n) : 0, lit: !off && n == 6, line: !future, diameter: 26)
                    .padding(.horizontal, 2)
                Circle()
                    .fill(Color.sky)
                    .frame(width: 4, height: 4)
                    .opacity(planned ? 1 : 0)
            }
            .opacity(future && !off ? 0.55 : 1)
            .contentShape(.rect)
        }
        .buttonStyle(PressScale(scale: 0.92))
        .disabled(type == .shabbat)
        .accessibilityLabel(label(future: future, off: off, planned: planned, n: n))
    }

    private func label(future: Bool, off: Bool, planned: Bool, n: Int) -> String {
        let base = DayKey.long(ds)
        if future { return planned ? String(localized: "\(base), changed") : base }
        return off ? base : String(localized: "\(base), \(n) of 6")
    }
}
