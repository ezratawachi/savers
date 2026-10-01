import SwiftUI

/// "Cambios de la IA": each change with its before and after and a switch, the ones that can't be made in
/// red with "Copiar para la IA", and "Aplicar".
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
            AppList {
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
                        Text("Apaga los que no quieras.")
                    }
                }
                if !proposal.problems.isEmpty {
                    Section {
                        ForEach(proposal.problems, id: \.self) { p in
                            Label(p, systemImage: "exclamationmark.triangle.fill")
                                .font(.reading(16))
                                .foregroundStyle(.warn)
                        }
                        Button(copied ? "Copiado" : "Copiar para la IA", systemImage: copied ? "checkmark" : "doc.on.doc") {
                            UIPasteboard.general.string = proposal.problemsMessage
                            copied = true
                        }
                        .foregroundStyle(.sky)
                    } header: {
                        Text(proposal.problems.count == 1 ? "No se puede aplicar" : "No se pueden aplicar")
                    } footer: {
                        Text("Pégaselo a la IA para que te dé el bloque corregido.")
                    }
                }
            }
            .navigationTitle("Cambios de la IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !proposal.changes.isEmpty {
                    Button(chosen.isEmpty ? "Cerrar sin cambios" : chosen.count == 1 ? "Aplicar 1 cambio" : "Aplicar \(chosen.count) cambios", action: apply)
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
        toast.show(picked.count == 1 ? "Cambio aplicado" : "\(picked.count) cambios aplicados")
        dismiss()
    }
}

/// "SAVERS" / "Normal · solo los jueves" / "5:55 → 5:45", and a list's lines under it.
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
