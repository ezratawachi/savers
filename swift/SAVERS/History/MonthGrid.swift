import SwiftUI

/// One month: its name and how many mornings were complete, then the days as rings that fill with each letter.
struct MonthGrid: View {
    @Environment(AppStore.self) private var store
    let month: MonthIndex
    let onOpen: (String) -> Void

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private static let weekdays = ["D", "L", "M", "M", "J", "V", "S"]

    var body: some View {
        let r = store.routine
        let today = store.today
        let dates = month.dates
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(DayKey.monthName(month))
                    .font(.display(24, relativeTo: .title2))
                    .foregroundStyle(.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(countLine(r, dates, today: today))
                    .font(.reading(15, relativeTo: .subheadline))
                    .foregroundStyle(.muted)
            }
            .padding(.trailing, 100)
            LazyVGrid(columns: Self.columns, spacing: 6) {
                ForEach(Self.weekdays.indices, id: \.self) { i in
                    Text(Self.weekdays[i])
                        .font(.reading(13, relativeTo: .caption).bold())
                        .foregroundStyle(.muted)
                        .accessibilityHidden(true)
                }
                ForEach(0..<DayKey.weekday(month.first), id: \.self) { _ in
                    Color.clear.frame(height: 1)
                }
                ForEach(dates, id: \.self) { ds in
                    DayCell(ds: ds, routine: r, today: today) { onOpen(ds) }
                }
            }
        }
    }

    private func countLine(_ r: Routine, _ dates: [String], today: String) -> String {
        let scheduled = dates.filter { $0 <= today && r.isScheduled($0) }
        let complete = scheduled.count { r.day($0).doneCount == 6 }
        if !scheduled.isEmpty {
            return "\(complete) de \(scheduled.count) \(scheduled.count == 1 ? "mañana completa" : "mañanas completas")"
        }
        return month.first > today ? "Por venir" : "Sin mañanas todavía"
    }
}

/// A day: a ring filled n/6 in terracotta (whole when complete), today with a blue edge, days to come
/// faded, and a blue dot on a day to come that was changed for itself.
private struct DayCell: View {
    let ds: String
    let routine: Routine
    let today: String
    let action: () -> Void

    var body: some View {
        let type = routine.dayType(ds)
        let d = routine.day(ds)
        let n = d.doneCount
        let future = ds > today
        let off = type == .shabbat || (type == .off && !d.hasContent)
        let planned = future && type != .shabbat && (d.type != nil || d.times != nil || d.mins != nil)
        let full = n == 6

        Button(action: action) {
            ZStack {
                if !off {
                    Circle().stroke(Color.line, lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: CGFloat(n) / 6)
                        .stroke(Color.dawn, style: StrokeStyle(lineWidth: 3, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
                if full { Circle().fill(Color.dawn) }
                if ds == today {
                    Circle().strokeBorder(Color.sky, lineWidth: 2).padding(3)
                }
                Text("\(DayKey.calendar.component(.day, from: DayKey.date(ds)))")
                    .font(.reading(14, relativeTo: .footnote).weight(off ? .regular : .bold))
                    .monospacedDigit()
                    .foregroundStyle(full ? Color.white : off ? Color.muted : Color.ink)
                if planned {
                    Circle().fill(Color.sky)
                        .frame(width: 4, height: 4)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 6)
                }
            }
            .padding(1.5)
            .aspectRatio(1, contentMode: .fit)
            .opacity(future && !off ? 0.4 : 1)
            .contentShape(.circle)
        }
        .buttonStyle(PressScale(scale: 0.94))
        .disabled(type == .shabbat)
        .accessibilityLabel(label(future: future, off: off, planned: planned, n: n))
    }

    private func label(future: Bool, off: Bool, planned: Bool, n: Int) -> String {
        let base = DayKey.long(ds)
        if future { return planned ? base + ", cambiado" : base }
        return off ? base : "\(base), \(n) de 6"
    }
}
