import SwiftUI

/// Settings › Talk with an AI: notes it always gets, what to talk about, sending it all, and pasting back
/// the changes it gives.
struct AssistantPage: View {
    @Environment(AppStore.self) private var store
    @Environment(Toast.self) private var toast
    /// A question to start with ("Write them with an AI" in Affirm), in place of the draft.
    var ask: String?
    @State private var notes = ""
    /// What to talk about stays here as a draft, until it's sent and beyond.
    @AppStorage("savers:aiQuestion") private var question = ""
    @State private var proposal: AIProposal?
    @State private var askingUndo = false
    @FocusState private var notesFocused: Bool

    var body: some View {
        CardList {
            Section {
                TextField("My work, what never moves, what I want to achieve", text: $notes, axis: .vertical)
                    .lineLimit(3...)
                    .focused($notesFocused)
                    .accessibilityLabel("Notes for the AI")
            } header: {
                Text("Notes for the AI")
            } footer: {
                Text("What the app doesn't know about you. They always go along.")
            }

            Section {
                TextField("Optional. For example: I don't have enough time to read", text: $question, axis: .vertical)
                    .lineLimit(2...)
                    .accessibilityLabel("What you want to talk about")
                ShareLink(item: AIPacket.text(store.routine, question: question), preview: SharePreview(String(localized: "My sunrise in Sunling"))) {
                    Label("Send to an AI", systemImage: "square.and.arrow.up")
                        .fontWeight(.bold)
                }
                .foregroundStyle(.sky)
                .cardRow()
            } header: {
                Text("What do you want to talk about?")
            } footer: {
                Text("It goes with instructions, your schedule, your affirmations, your Imagine questions, your notes and what you checked off in the last \(AIPacket.weeks) weeks. Not what you write in \(Letter.escritura.name).")
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
                Text("Changes from the AI")
            } footer: {
                Text("When you accept what it suggests, the AI gives you a change block. Copy its whole reply and tap Paste: you see each change before it's applied.")
            }

            if store.aiUndo != nil {
                Section {
                    Button("Undo the AI's last changes", role: .destructive) { askingUndo = true }
                        .foregroundStyle(.warn)
                        .cardRow()
                }
            }
        }
        .navigationTitle("Talk with an AI")
        .confirmationDialog("Undo the AI's last changes?", isPresented: $askingUndo, titleVisibility: .visible) {
            Button("Undo changes", role: .destructive) {
                store.undoAI()
                toast.show(String(localized: "Changes undone"))
            }
        } message: {
            Text(store.aiUndo?.changedSince(settings: store.settings, days: store.days) == true
                 ? "Everything goes back to how it was before they were applied. What you changed afterwards is lost too."
                 : "Everything goes back to how it was before they were applied.")
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $proposal) { ChangesSheet(proposal: $0) }
        .onAppear {
            notes = store.settings.aiNotes
            if let ask { question = ask }
            #if DEBUG
            // `-pegar archivo`: what a tap on Paste would bring, since the simulator can't tap it.
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
                toast.show(String(localized: "Those changes are already in your app"))
            } else {
                proposal = p
            }
        } catch {
            toast.show(error.message)
        }
    }
}
