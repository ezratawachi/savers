import SwiftUI

/// Ajustes › Horario: what each weekday is, and the usual hours of Normal and Gym. Changes as you tap,
/// like iOS Settings.
struct ScheduleSettings: View {
    @Environment(AppStore.self) private var store
    @State private var tab: DayType = .normal
    @State private var chosenTab = false
    @State private var editing: ScheduleEdit?

    var body: some View {
        let r = store.routine
        let kinds = [DayType.normal, .gym].filter { r.settings.schedule?.type($0) != nil }
        let shown = kinds.contains(tab) ? tab : kinds.first ?? .normal

        AppList {
            Section {
                ForEach(0..<6, id: \.self) { w in
                    Picker(Weekday.names[w].capitalizedFirst, selection: Binding { r.weekType(w) } set: { store.setWeekType(w, $0) }) {
                        ForEach(DayType.choosable, id: \.self) { Text($0.name).tag($0) }
                    }
                    .tint(.muted)
                }
                LabeledContent("Sábado", value: "Shabbat")
            } header: {
                Text("Días")
            } footer: {
                Text("Para un solo día, como un feriado o un gym cancelado, tócalo en Hoy o en Historial.")
            }

            if kinds.isEmpty {
                Section("Horas") {
                    Text("Tus horas se cargan al entrar con Google.")
                        .foregroundStyle(.muted)
                }
            } else {
                Section {
                    if kinds.count > 1 {
                        SegmentedChoice(
                            label: "Horario",
                            options: kinds.map { k in
                                let ws = r.days(of: k)
                                return .init(id: k, title: k.name, note: ws.isEmpty ? "ningún día" : Weekday.list(ws))
                            },
                            selection: Binding { shown } set: { tab = $0 }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Horas")
                }
                ForEach(r.stepLines(shown), id: \.group) { g in
                    Section {
                        ForEach(g.lines) { line in
                            stepRows(line, shown)
                        }
                    } header: {
                        if let title = g.group.title { Text(title) }
                    } footer: {
                        if g.group == TypeSchedule.Group.allCases.last(where: { r.settings.schedule?.type(shown)?[$0].isEmpty == false }) {
                            Text("Toca una hora para cambiarla en todos los días de \(shown.name) o solo en uno. Los minutos de Silencio y Lectura, igual.")
                        }
                    }
                }
            }
        }
        .navigationTitle("Horario")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Opens on the kind today is, the first time.
            guard !chosenTab else { return }
            tab = r.dayType(store.today) == .gym ? .gym : .normal
            chosenTab = true
        }
        .sheet(item: $editing) { edit in
            Group {
                switch edit {
                case .step(let kind, let id): StepTimeSheet(kind: kind, id: id)
                case .minutes(let kind, let letter): MinutesSheet(kind: kind, letter: letter)
                case .windDown: WindDownSheet()
                }
            }
            .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private func stepRows(_ line: Routine.StepLine, _ kind: DayType) -> some View {
        Button {
            if let id = line.step.id { editing = .step(kind, id) }
        } label: {
            SettingsRow(title: line.step.title ?? "", detail: line.summary, chevron: true)
        }
        ForEach(line.letters) { l in
            if l.letter.usualMinutes != nil {
                Button {
                    editing = .minutes(kind, l.letter)
                } label: {
                    SettingsRow(title: l.letter.name, detail: l.info, chevron: true, sub: true)
                }
            } else {
                SettingsRow(title: l.letter.name, detail: l.info, chevron: false, sub: true)
            }
        }
        if let info = line.windDown {
            Button {
                editing = .windDown
            } label: {
                SettingsRow(title: "Prepararte", detail: info, chevron: true, sub: true)
            }
        }
        ForEach(line.warnings, id: \.self) { w in
            Label(w, systemImage: "exclamationmark.triangle.fill")
                .font(.reading(15, relativeTo: .subheadline))
                .foregroundStyle(.warn)
        }
    }
}

enum ScheduleEdit: Identifiable {
    case step(DayType, String)
    case minutes(DayType, Letter)
    case windDown

    var id: String {
        switch self {
        case .step(let k, let id): "\(k.rawValue)-\(id)"
        case .minutes(let k, let l): "\(k.rawValue)-\(l.rawValue)"
        case .windDown: "windDown"
        }
    }
}

/// "Te paras · 5:20 · jue 5:10 ›"; a letter under its block is indented.
struct SettingsRow: View {
    let title: String
    let detail: String
    var chevron = false
    var sub = false

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(sub ? .reading(16) : .reading().bold())
                .foregroundStyle(.ink)
                .padding(.leading, sub ? 16 : 0)
            Spacer(minLength: 8)
            Text(detail)
                .font(.reading(15, relativeTo: .subheadline))
                .monospacedDigit()
                .foregroundStyle(.muted)
                .multilineTextAlignment(.trailing)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.muted)
                .opacity(chevron ? 0.6 : 0)
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
