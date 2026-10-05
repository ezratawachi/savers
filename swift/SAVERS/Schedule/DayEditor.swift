import SwiftUI

/// One date: what it is (its weekday's kind, or another just this day) and, from today on, its hours and
/// minutes. Tapping an hour opens the wheel under it; what's changed for this date shows in blue.
struct DayEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let ds: String

    /// The row whose wheel is open: a step id, or a letter's key for its minutes.
    @State private var picking: String?

    var body: some View {
        let r = store.routine
        let type = r.dayType(ds)
        let w = DayKey.weekday(ds)
        let editable = ds >= store.today

        VStack(alignment: .leading, spacing: 18) {
            SegmentedChoice(
                label: String(localized: "This day is"),
                options: r.types.map { .init(id: $0, title: $0.name, note: $0 == r.weekType(w) ? Weekday.plural(w) : nil) },
                selection: Binding { type } set: { new in
                    picking = nil
                    store.setDateType(ds, new)
                }
            )
            if !type.hasSunrise {
                Note(String(localized: "Sunling rests this day: it doesn't break your sunrises in a row."))
            } else if let t = r.settings.schedule?.type(type) {
                timeline(r, t, editable: editable)
                minutes(r, type, editable: editable)
                if editable {
                    VStack(alignment: .leading, spacing: 4) {
                        Note(String(localized: "What you change here is just for this day."))
                        if r.dateEdited(ds) {
                            Button("Back to the usual") {
                                withAnimation(motion) {
                                    picking = nil
                                    store.resetDate(ds)
                                }
                            }
                            .font(.reading().bold())
                            .foregroundStyle(.sky)
                            .frame(minHeight: 44)
                        }
                    }
                }
            } else {
                Note(String(localized: "Your schedule loads when you sign in with Google."))
            }
        }
    }

    private var motion: Animation? { Motion.pick(Motion.height, reduce: reduceMotion) }

    // MARK: Hours

    private func timeline(_ r: Routine, _ t: TypeSchedule, editable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(TypeSchedule.Group.allCases, id: \.self) { g in
                let list = t[g]
                if !list.isEmpty {
                    if let title = g.title {
                        GroupTitle(text: title)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(list.indices, id: \.self) { i in
                            stepRow(r, list[i], group: g, last: i == list.count - 1, editable: editable)
                        }
                    }
                    .opacity(g == .night ? 0.6 : 1)
                }
            }
        }
    }

    @ViewBuilder
    private func stepRow(_ r: Routine, _ st: Step, group g: TypeSchedule.Group, last: Bool, editable: Bool) -> some View {
        let id = st.id ?? st.label
        let time = r.time(of: st, on: ds)
        let edited = !(store.days[ds]?.times?[id] ?? "").isEmpty
        let key = g == .steps && st.id != nil && st.id == r.settings.schedule?.type(r.dayType(ds))?.sunriseBlockID
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                timeCell(time.isEmpty ? "—" : time, edited: edited, open: picking == id, editable: editable) {
                    toggle(id)
                }
                .accessibilityLabel(edited ? "Time of \(st.title ?? ""), \(time), changed for this day" : "Time of \(st.title ?? ""), \(time)")
                VStack(alignment: .leading, spacing: 2) {
                    Text(st.title ?? "")
                        .font(.reading().bold())
                        .foregroundStyle(.ink)
                    if let detail = st.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.reading(15, relativeTo: .subheadline))
                            .foregroundStyle(.muted)
                    }
                }
                .padding(.leading, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(key ? Color.sky : Color.line)
                        .frame(width: 9, height: 9)
                        .offset(y: 7)
                }
            }
            .padding(.vertical, 7)
            .background(alignment: .topLeading) {
                // The rail that joins the day's hours; an open wheel interrupts it.
                if !last {
                    Rectangle()
                        .fill(Color.line)
                        .frame(width: 1.5)
                        .padding(.top, 24)
                        .padding(.bottom, picking == id ? 4 : -14)
                        .padding(.leading, TimeCell.width + 10 + 3.75)
                }
            }
            if picking == id {
                TimeWheel(label: String(localized: "Time of \(st.title ?? "")"), time: time) { store.setDateTime(ds, stepID: id, $0) }
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }
        }
    }

    // MARK: Minutes

    private func minutes(_ r: Routine, _ type: DayType, editable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupTitle(text: String(localized: "Minutes"))
            ForEach([Letter.silencio, .lectura]) { l in
                let n = r.minutesOn(type, l, on: ds)
                let edited = Routine.valid(store.days[ds]?.mins?[l.rawValue]) != nil
                VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        timeCell(String(localized: "\(n) min"), edited: edited, open: picking == l.rawValue, editable: editable) {
                            toggle(l.rawValue)
                        }
                        .accessibilityLabel(edited ? "Minutes of \(l.name), \(n), changed for this day" : "Minutes of \(l.name), \(n)")
                        Text(l.name)
                            .font(.reading().bold())
                            .foregroundStyle(.ink)
                            .padding(.leading, 16)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 7)
                    if picking == l.rawValue {
                        MinutesWheel(label: String(localized: "Minutes of \(l.name)"), minutes: n) { store.setDateMinutes(ds, l, $0) }
                            .transition(.opacity)
                    }
                }
            }
        }
    }

    private func timeCell(_ text: String, edited: Bool, open: Bool, editable: Bool, action: @escaping () -> Void) -> some View {
        TimeCell(text: text, edited: edited, open: open, editable: editable, action: action)
    }

    private func toggle(_ id: String) {
        withAnimation(motion) { picking = picking == id ? nil : id }
    }
}

/// An hour or minutes in a pill; on today and days to come it's a button that opens its wheel.
private struct TimeCell: View {
    static let width: CGFloat = 86
    let text: String
    let edited: Bool
    let open: Bool
    let editable: Bool
    let action: () -> Void

    var body: some View {
        let label = Text(text)
            .font(.reading(16, relativeTo: .body).bold())
            .monospacedDigit()
            .foregroundStyle(edited || open ? Color.sky : Color.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        if editable {
            Button(action: action) {
                label
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(open ? Color.sky.opacity(0.14) : Color.surface2, in: .capsule)
                    .frame(width: Self.width, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(PressScale())
            .accessibilityHint(open ? "Closes the wheel" : "Opens the wheel to change it")
        } else {
            label.frame(width: Self.width, alignment: .leading)
        }
    }
}

/// "The night before", "Later", "Minutes"
private struct GroupTitle: View {
    let text: String

    var body: some View {
        // Like every section head in the app: Today's blocks, Settings' groups.
        Text(text)
            .font(.reading(15, relativeTo: .subheadline).bold())
            .foregroundStyle(.muted)
            .padding(.top, 14)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

extension TypeSchedule.Group {
    var title: String? {
        switch self {
        case .night: String(localized: "The night before")
        case .steps: nil
        case .later: String(localized: "Later")
        }
    }
}
