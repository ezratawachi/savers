import SwiftUI

/// Settings › Schedule › a kind of day: its name, its blocks and hours if it has the sunrise, and duplicating
/// or deleting it.
struct KindPage: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let id: String

    @State private var name = ""
    @FocusState private var naming: Bool
    @State private var editing: ScheduleEdit?
    @State private var addingBlock = false
    /// A block just made, until its sheet closes: then it opens.
    @State private var madeBlock: String?
    @State private var askingDelete = false
    /// The copy just made: its page opens.
    @State private var copy: String?

    var body: some View {
        let r = store.routine
        if let kind = r.kind(id), !kind.deleted {
            page(r, kind)
        }
    }

    private func page(_ r: Routine, _ kind: DayType) -> some View {
        let ws = r.days(of: kind)
        let taken = r.kind(named: name, except: id)
        let canDelete = !kind.hasSunrise || r.types.count(where: \.hasSunrise) > 1

        return CardList {
            Section {
                TextField(kind.name, text: $name)
                    .focused($naming)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Name")
            } header: {
                Text("Name")
            } footer: {
                if let taken {
                    Text("You already have a kind called \(taken.name).")
                        .foregroundStyle(.warn)
                } else {
                    let days = ws.isEmpty
                        ? String(localized: "No day of your week is \(kind.name) now.")
                        : String(localized: "\(Weekday.plurals(ws).capitalizedFirst) are \(kind.name).")
                    Text(kind.hasSunrise ? days : days + " " + String(localized: "A day of rest has no hours. Sunling rests, and it doesn't break your sunrises in a row."))
                }
            }

            if kind.hasSunrise, r.settings.schedule?.type(kind) == nil {
                Section("Hours") {
                    Text("Your hours load when you sign in with Google.")
                        .foregroundStyle(.muted)
                }
            } else if kind.hasSunrise {
                let groups = r.stepLines(kind)
                ForEach(groups, id: \.group) { g in
                    Section {
                        ForEach(g.lines) { line in
                            stepRows(line, kind)
                        }
                    } header: {
                        Text(g.group.title ?? String(localized: "In the morning"))
                    }
                }
                Section {
                    Button {
                        addingBlock = true
                    } label: {
                        Label("New block", systemImage: "plus")
                            .font(.reading().bold())
                            .foregroundStyle(.sky)
                    }
                    .cardRow()
                } footer: {
                    Text("Tap a block to change its hour on every \(kind.name) day or on just one, its name, or the steps it holds. The same goes for the minutes of \(Letter.silencio.name) and \(Letter.lectura.name).")
                }
            }

            Section {
                Button {
                    copy = store.addKind(named: r.copyName(kind.name), from: .copy(id))
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                        .font(.reading().bold())
                        .foregroundStyle(.sky)
                }
                .cardRow()
                Button(role: .destructive) {
                    askingDelete = true
                } label: {
                    Label("Delete \(kind.name)", systemImage: "trash")
                        .font(.reading().bold())
                        .foregroundStyle(.warn)
                }
                .cardRow()
                .disabled(!canDelete)
                .opacity(canDelete ? 1 : 0.4)
            } footer: {
                if !canDelete {
                    Text("Keep at least one kind with the sunrise.")
                }
            }
        }
        .navigationTitle(kind.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { name = kind.name }
        .onSubmit { commitName(kind) }
        .onChange(of: naming) { _, on in
            if !on { commitName(kind) }
        }
        .onDisappear { commitName(kind) }
        .sheet(item: $editing) { edit in
            Group {
                switch edit {
                case .step(let kind, let id): StepTimeSheet(kind: kind, id: id)
                case .minutes(let kind, let letter): MinutesSheet(kind: kind, letter: letter)
                case .windDown: WindDownSheet()
                }
            }
            .presentationDetents(edit.isStep ? [.medium, .large] : [.medium])
        }
        .sheet(isPresented: $addingBlock, onDismiss: {
            if let b = madeBlock { editing = .step(kind, b) }
            madeBlock = nil
        }) {
            NewBlockSheet(kind: kind) { madeBlock = $0 }
        }
        .confirmationDialog("Delete \(kind.name)?", isPresented: $askingDelete, titleVisibility: .visible) {
            Button("Delete \(kind.name)", role: .destructive) {
                store.deleteKind(kind)
                dismiss()
            }
        } message: {
            Text(deleteMessage(r, kind))
        }
        .navigationDestination(item: $copy) { KindPage(id: $0) }
    }

    /// "Wednesdays and Fridays use Gym. From today they're Normal. The days that passed stay as they were."
    private func deleteMessage(_ r: Routine, _ kind: DayType) -> String {
        let ws = r.days(of: kind)
        let to = r.fallback(for: kind)?.name ?? ""
        var lines: [String] = []
        if !ws.isEmpty {
            lines.append(String(localized: "\(Weekday.plurals(ws).capitalizedFirst) use \(kind.name). From today they're \(to)."))
        }
        if !r.datesChanged(to: kind).isEmpty {
            lines.append(String(localized: "The days you changed to \(kind.name) become \(to)."))
        }
        lines.append(String(localized: "The days that passed stay as they were."))
        return lines.joined(separator: " ")
    }

    /// Empty or taken goes back to the name it had.
    private func commitName(_ kind: DayType) {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, n != kind.name, store.routine.kind(named: n, except: id) == nil else {
            name = kind.name
            return
        }
        store.renameKind(kind, n)
        name = n
    }

    @ViewBuilder
    private func stepRows(_ line: Routine.StepLine, _ kind: DayType) -> some View {
        Button {
            if let id = line.step.id { editing = .step(kind, id) }
        } label: {
            SettingsRow(title: line.step.title ?? "", detail: line.summary, chevron: true)
        }
        .cardRow()
        ForEach(line.letters) { l in
            if l.letter.usualMinutes != nil {
                Button {
                    editing = .minutes(kind, l.letter)
                } label: {
                    SettingsRow(title: l.letter.name, detail: l.info, chevron: true, sub: true)
                }
                .cardRow()
            } else {
                SettingsRow(title: l.letter.name, detail: l.info, chevron: false, sub: true)
            }
        }
        if let info = line.windDown {
            Button {
                editing = .windDown
            } label: {
                SettingsRow(title: String(localized: "Wind down"), detail: info, chevron: true, sub: true)
            }
            .cardRow()
        }
        ForEach(line.warnings, id: \.self) { w in
            Label(w, systemImage: "exclamationmark.triangle.fill")
                .font(.reading(15, relativeTo: .subheadline))
                .foregroundStyle(.warn)
        }
    }
}
