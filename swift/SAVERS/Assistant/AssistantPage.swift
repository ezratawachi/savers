import SwiftUI

/// Ajustes › Hablar con una IA: notes it always gets, what to talk about, sending it all, and pasting back
/// the changes it gives.
struct AssistantPage: View {
    @Environment(AppStore.self) private var store
    @Environment(Toast.self) private var toast
    @State private var notes = ""
    /// What to talk about stays here as a draft, until it's sent and beyond.
    @AppStorage("savers:aiQuestion") private var question = ""
    @State private var proposal: AIProposal?
    @State private var askingUndo = false
    @FocusState private var notesFocused: Bool

    var body: some View {
        CardList {
            Section {
                TextField("Mi trabajo, lo que no se mueve, lo que quiero lograr", text: $notes, axis: .vertical)
                    .lineLimit(3...)
                    .focused($notesFocused)
                    .accessibilityLabel("Notas para la IA")
            } header: {
                Text("Notas para la IA")
            } footer: {
                Text("Lo que la app no sabe de ti. Van siempre.")
            }

            Section {
                TextField("Opcional. Por ejemplo: no me alcanza el tiempo para leer", text: $question, axis: .vertical)
                    .lineLimit(2...)
                    .accessibilityLabel("De qué quieres hablar")
                ShareLink(item: AIPacket.text(store.routine, question: question), preview: SharePreview("Mi amanecer en Sunling")) {
                    Label("Mandar a la IA", systemImage: "square.and.arrow.up")
                        .fontWeight(.bold)
                }
                .foregroundStyle(.sky)
                .cardRow()
            } header: {
                Text("¿De qué quieres hablar?")
            } footer: {
                Text("Se manda con instrucciones, tu horario, tus afirmaciones, tu visualización, tus notas y lo que marcaste en las últimas \(AIPacket.weeks) semanas. Lo que escribes en Escribe, no.")
            }

            Section {
                // The system's own button: it pastes without asking for permission and never blocks the app.
                PasteButton(payloadType: String.self) { texts in
                    let text = texts.joined(separator: "\n")
                    Task { @MainActor in read(text) }
                }
                .tint(.sky)
                .labelStyle(.titleAndIcon)
            } header: {
                Text("Cambios de la IA")
            } footer: {
                Text("Cuando aceptes lo que te propone, la IA te da un bloque de cambios. Copia su respuesta entera y toca Pegar: ves cada cambio antes de aplicarlo.")
            }

            if store.aiUndo != nil {
                Section {
                    Button("Deshacer los últimos cambios de la IA", role: .destructive) { askingUndo = true }
                        .foregroundStyle(.warn)
                        .cardRow()
                }
            }
        }
        .navigationTitle("Hablar con una IA")
        .confirmationDialog("¿Deshacer los últimos cambios de la IA?", isPresented: $askingUndo, titleVisibility: .visible) {
            Button("Deshacer cambios", role: .destructive) {
                store.undoAI()
                toast.show("Cambios deshechos")
            }
        } message: {
            Text(store.aiUndo?.changedSince(settings: store.settings, days: store.days) == true
                 ? "Todo vuelve a como estaba antes de aplicarlos. También se pierde lo que cambiaste después."
                 : "Todo vuelve a como estaba antes de aplicarlos.")
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $proposal) { ChangesSheet(proposal: $0) }
        .onAppear {
            notes = store.settings.aiNotes
            #if DEBUG
            // `-pegar archivo`: what a tap on Pegar would bring, since the simulator can't tap it.
            if let path = Scenario.packetPath {
                try? AIPacket.text(store.routine, question: question).write(toFile: path, atomically: true, encoding: .utf8)
            }
            if let text = Scenario.pasted {
                Scenario.pasted = nil
                read(text)
            }
            #endif
        }
        .onChange(of: notes) { _, new in
            if new != store.settings.aiNotes { store.setAINotes(new) }
        }
        .onChange(of: notesFocused) { _, focused in
            guard !focused else { return }
            notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            store.flush()
        }
        .onChange(of: store.settings.aiNotes) { _, new in
            // Notes that arrive from the cloud, unless they're being written here.
            if !notesFocused && new != notes { notes = new }
        }
    }

    private func read(_ text: String) {
        do {
            let p = try AIProposal(text: text, routine: store.routine)
            if p.changes.isEmpty && p.problems.isEmpty {
                toast.show("Esos cambios ya están en tu app")
            } else {
                proposal = p
            }
        } catch {
            toast.show(error.message)
        }
    }
}
