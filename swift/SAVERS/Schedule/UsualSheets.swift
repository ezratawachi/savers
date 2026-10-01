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
                TimeWheel(label: "Hora de \(st.title ?? "")", time: r.usualTime(st, weekday: weekday)) {
                    store.setStepTime(kind, id: id, weekday: weekday, $0)
                }
            } foot: {
                if let w = weekday {
                    Note("Solo \(Weekday.plural(w)).")
                    if r.ownTime(st, weekday: w) != nil {
                        UsualButton("Usar la misma hora que los demás") {
                            store.setStepTime(kind, id: id, weekday: w, st.time ?? "")
                        }
                    }
                } else {
                    Note(own.isEmpty
                         ? days.isEmpty ? "Ningún día usa este horario ahora." : "Para \(Weekday.list(days))."
                         : "\(Weekday.plurals(own).capitalizedFirst) tienen otra hora. Si la cambias aquí, todos quedan iguales.")
                }
            }
        }
    }
}

/// Silencio's or Lectura's minutes, the same way as an hour.
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
            MinutesWheel(label: "Minutos de \(letter.name)", minutes: r.usualMinutes(kind, letter, weekday: weekday)) {
                store.setUsualMinutes(kind, letter, weekday: weekday, $0)
            }
        } foot: {
            if let w = weekday {
                Note("Solo \(Weekday.plural(w)).")
                if r.ownMinutes(kind, letter, weekday: w) != nil {
                    UsualButton("Usar los mismos minutos que los demás") {
                        store.setUsualMinutes(kind, letter, weekday: w, nil)
                    }
                }
            } else {
                Note(own.isEmpty
                     ? days.isEmpty ? "Ningún día usa este horario ahora." : "Para \(Weekday.list(days))."
                     : "\(Weekday.plurals(own).capitalizedFirst) tienen otros minutos. Si los cambias aquí, todos quedan iguales.")
            }
        }
    }
}

/// How long before "Dormido" "Prepararte para dormir" arrives: one number for every night.
struct WindDownSheet: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        UsualSheet(title: "Prepararte", days: [], weekday: .constant(nil)) {
            MinutesWheel(label: "Minutos antes de Dormido", minutes: store.routine.windDown, choices: Array(stride(from: 15, through: 90, by: 5))) {
                store.setWindDown($0)
            }
        } foot: {
            Note("Igual todas las noches. El aviso Prepararte para dormir llega estos minutos antes de Dormido.")
        }
    }
}

/// Title and Listo, "Todos | lun | mar…", the wheel, and what the choice means.
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
                            label: "Días",
                            options: [.init(id: nil, title: "Todos")] + days.map { .init(id: Optional($0), title: Weekday.keys[$0]) },
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
                    Button("Listo") { dismiss() }
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
