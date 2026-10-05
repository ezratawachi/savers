import SwiftUI

/// Under a block's hour: its name, which of the six steps it holds, and deleting it. A step lives in one block
/// of a kind; the sunrise's own block takes back the ones you send away, and it can't be deleted.
struct BlockDetails: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let kind: DayType
    let id: String

    @State private var name = ""
    @FocusState private var naming: Bool
    @State private var askingDelete = false

    var body: some View {
        let r = store.routine
        let t = r.settings.schedule?.type(kind)
        let group = TypeSchedule.Group.allCases.first { g in t?[g].contains { $0.id == id } == true }
        let sunrise = t?.sunriseBlockID
        let isSunrise = id == sunrise
        let sunriseName = sunrise.flatMap { r.step(kind, id: $0) }?.label ?? ""

        if let st = r.step(kind, id: id) {
            CardSections {
                Section("Name") {
                    TextField(st.title ?? "", text: $name)
                        .focused($naming)
                        .submitLabel(.done)
                        .accessibilityLabel("Name")
                        .onSubmit { commitName(st) }
                }

                if group != .night, let sunrise {
                    Section {
                        ForEach(Letter.allCases) { l in
                            stepRow(r, l, sunrise: sunrise, isSunrise: isSunrise)
                        }
                    } header: {
                        Text("Steps in this block")
                    } footer: {
                        Text(isSunrise
                             ? "To take a step out of \(st.label), open the block where you want it."
                             : "Tap a step to bring it here. Tap it again and it goes back to \(sunriseName).")
                    }
                }

                if !isSunrise {
                    Section {
                        Button(role: .destructive) {
                            askingDelete = true
                        } label: {
                            Label("Delete block", systemImage: "trash")
                                .font(.reading().bold())
                                .foregroundStyle(.warn)
                        }
                        .cardRow()
                    }
                }
            }
            .padding(.top, 14)
            .onAppear { name = st.title ?? "" }
            .onChange(of: naming) { _, on in
                if !on { commitName(st) }
            }
            .onDisappear { commitName(st) }
            .confirmationDialog("Delete \(st.label)?", isPresented: $askingDelete, titleVisibility: .visible) {
                Button("Delete block", role: .destructive) {
                    store.removeBlock(kind, id: id)
                    dismiss()
                }
            } message: {
                Text(st.letterKeys.isEmpty ? "On every \(kind.name) day." : "On every \(kind.name) day. Its steps go back to \(sunriseName).")
            }
        }
    }

    @ViewBuilder
    private func stepRow(_ r: Routine, _ l: Letter, sunrise: String, isSunrise: Bool) -> some View {
        let holder = r.block(holding: l, in: kind)
        let here = holder?.id == id
        Button {
            store.moveStep(l, in: kind, to: here ? sunrise : id)
        } label: {
            HStack(spacing: 8) {
                Text(l.name)
                    .foregroundStyle(.ink)
                Spacer(minLength: 8)
                if here {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.sky)
                } else if let holder {
                    Text(holder.label)
                        .foregroundStyle(.muted)
                }
            }
        }
        .cardRow()
        // In the sunrise's block a step stays until another block takes it.
        .disabled(here && isSunrise)
        .accessibilityAddTraits(here ? .isSelected : [])
        .accessibilityHint(here ? (isSunrise ? Text(verbatim: "") : Text("Sends it back to the sunrise")) : Text("Brings it to this block"))
        .sensoryFeedback(.selection, trigger: here)
    }

    /// Empty goes back to the name it had.
    private func commitName(_ st: Step) {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else {
            name = st.title ?? ""
            return
        }
        guard n != st.title else { return }
        store.renameBlock(kind, id: id, n)
    }
}
