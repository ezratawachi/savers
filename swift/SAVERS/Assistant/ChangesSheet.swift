import SwiftUI

/// "Changes from the AI": each change with its before and after and a switch, the ones that can't be made
/// in red with "Copy for the AI", and "Apply".
struct ChangesSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(Toast.self) private var toast
    @Environment(\.dismiss) private var dismiss
    let proposal: AIProposal
    @State private var off: Set<Int> = []
    @State private var copied = false

    private var chosen: [AIChange] { proposal.changes.filter { !off.contains($0.id) } }

    var body: some View {
        NavigationStack {
            CardList {
                if !proposal.changes.isEmpty {
                    Section {
                        ForEach(proposal.changes) { c in
                            Toggle(isOn: Binding { !off.contains(c.id) } set: { on in
                                if on { off.remove(c.id) } else { off.insert(c.id) }
                            }) {
                                ChangeRow(change: c)
                            }
                            .tint(.sky)
                        }
                    } footer: {
                        Text("Turn off the ones you don't want.")
                    }
                }
                if !proposal.problems.isEmpty {
                    Section {
                        ForEach(proposal.problems, id: \.self) { p in
                            Label(p, systemImage: "exclamationmark.triangle.fill")
                                .font(.reading(16))
                                .foregroundStyle(.warn)
                        }
                        Button(copied ? "Copied" : "Copy for the AI", systemImage: copied ? "checkmark" : "doc.on.doc") {
                            UIPasteboard.general.string = proposal.problemsMessage
                            copied = true
                        }
                        .foregroundStyle(.sky)
                        .cardRow()
                    } header: {
                        Text(proposal.problems.count == 1 ? "This one can't be applied" : "These can't be applied")
                    } footer: {
                        Text("Paste it to the AI so it gives you the fixed block.")
                    }
                }
            }
            .navigationTitle("Changes from the AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !proposal.changes.isEmpty {
                    Button(chosen.isEmpty ? String(localized: "Close without changes") : String(localized: "Apply \(chosen.count) changes"), action: apply)
                        .buttonStyle(PrimaryButton())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.bg)
                }
            }
        }
        .tint(.sky)
    }

    private func apply() {
        let picked = chosen
        guard !picked.isEmpty else { return dismiss() }
        store.applyAI(picked)
        toast.show(String(localized: "\(picked.count) changes applied"))
        dismiss()
    }
}

/// "Sunrise" / "Normal · Thursdays only" / "5:55 → 5:45", and a list's lines under it.
private struct ChangeRow: View {
    let change: AIChange

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(change.title)
                .font(.reading().bold())
                .foregroundStyle(.ink)
            if !change.context.isEmpty {
                Text(change.context)
                    .font(.reading(15, relativeTo: .subheadline))
                    .foregroundStyle(.muted)
            }
            if !change.detail.isEmpty {
                Text(change.detail)
                    .font(.reading(16))
                    .foregroundStyle(.ink)
            }
            ForEach(change.lines, id: \.self) { line in
                Text(line)
                    .font(.reading(15, relativeTo: .subheadline))
                    .foregroundStyle(.ink)
            }
        }
        .padding(.vertical, 2)
    }
}
