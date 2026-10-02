import SwiftUI

/// One hour of the schedule: for all the days of its kind, or for one weekday only.
struct StepTimeSheet: View {
    @Environment(AppStore.self) private var store
    let kind: DayType
    let id: String
    /// nil: all the days.
    @State private var weekday: Int?

    var body: some View {
        let r = store.routine
        if let st = r.step(kind, id: id) {
            let days = r.days(of: kind)
            let own = days.filter { r.ownTime(st, weekday: $0) != nil }
            UsualSheet(title: st.title ?? "", days: days, weekday: $weekday) {
                TimeWheel(label: String(localized: "Time of \(st.title ?? "")"), time: r.usualTime(st, weekday: weekday)) {
                    store.setStepTime(kind, id: id, weekday: weekday, $0)
                }
            } foot: {
                if let w = weekday {
                    Note(String(localized: "\(Weekday.plural(w)) only."))
                    if r.ownTime(st, weekday: w) != nil {
                        UsualButton(String(localized: "Use the same time as the others")) {
                            store.setStepTime(kind, id: id, weekday: w, st.time ?? "")
                        }
                    }
                } else {
                    Note(own.isEmpty
                         ? days.isEmpty ? String(localized: "No day uses this schedule now.") : String(localized: "For \(Weekday.list(days)).")
                         : String(localized: "\(Weekday.plurals(own).capitalizedFirst) have another time. If you change it here, they all end up the same."))
                }
            }
        }
    }
}

/// Breathe's or Read's minutes, the same way as an hour.
struct MinutesSheet: View {
    @Environment(AppStore.self) private var store
    let kind: DayType
    let letter: Letter
    @State private var weekday: Int?

    var body: some View {
        let r = store.routine
        let days = r.days(of: kind)
        let own = days.filter { r.ownMinutes(kind, letter, weekday: $0) != nil }
        UsualSheet(title: letter.name, days: days, weekday: $weekday) {
            MinutesWheel(label: String(localized: "Minutes of \(letter.name)"), minutes: r.usualMinutes(kind, letter, weekday: weekday)) {
                store.setUsualMinutes(kind, letter, weekday: weekday, $0)
            }
        } foot: {
            if let w = weekday {
                Note(String(localized: "\(Weekday.plural(w)) only."))
                if r.ownMinutes(kind, letter, weekday: w) != nil {
                    UsualButton(String(localized: "Use the same minutes as the others")) {
                        store.setUsualMinutes(kind, letter, weekday: w, nil)
                    }
                }
            } else {
                Note(own.isEmpty
                     ? days.isEmpty ? String(localized: "No day uses this schedule now.") : String(localized: "For \(Weekday.list(days)).")
                     : String(localized: "\(Weekday.plurals(own).capitalizedFirst) have other minutes. If you change them here, they all end up the same."))
            }
        }
    }
}

/// How long before bedtime ("Dormido") the wind-down notice arrives: one number for every night.
struct WindDownSheet: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        UsualSheet(title: String(localized: "Wind down"), days: [], weekday: .constant(nil)) {
            MinutesWheel(label: String(localized: "Minutes before bedtime"), minutes: store.routine.windDown, choices: Routine.windDownChoices) {
                store.setWindDown($0)
            }
        } foot: {
            Note(String(localized: "The same every night. The wind-down notice arrives this many minutes before bedtime."))
        }
    }
}

/// Title and Done, "All | Mon | Tue…", the wheel, and what the choice means.
private struct UsualSheet<Wheel: View, Foot: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let days: [Int]
    @Binding var weekday: Int?
    @ViewBuilder let wheel: Wheel
    @ViewBuilder let foot: Foot

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if days.count > 1 {
                        SegmentedChoice(
                            label: String(localized: "Days"),
                            options: [.init(id: nil, title: String(localized: "All"))] + days.map { .init(id: Optional($0), title: Weekday.short[$0]) },
                            selection: $weekday
                        )
                    }
                    wheel
                        .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 4) { foot }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(.bg)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(.sky)
    }
}

private struct UsualButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(title, action: action)
            .font(.reading().bold())
            .foregroundStyle(.sky)
            .frame(minHeight: 44)
    }
}
