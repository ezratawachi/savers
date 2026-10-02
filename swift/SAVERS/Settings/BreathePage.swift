import SwiftUI

/// Settings › Breathe: the line its card shows under the name, in your words.
struct BreathePage: View {
    @Environment(AppStore.self) private var store
    @State private var note = ""
    @FocusState private var focused: Bool

    var body: some View {
        CardList {
            Section {
                TextField(AppSettings.breatheDefault, text: $note)
                    .focused($focused)
                    .submitLabel(.done)
                    .accessibilityLabel("Under \(Letter.silencio.name)")
            } header: {
                Text("Under \(Letter.silencio.name)")
            } footer: {
                Text("How you breathe, meditate or pray each morning: an app, a prayer, a place. Left empty, it says “\(AppSettings.breatheDefault)”.")
            }
        }
        .navigationTitle(Letter.silencio.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { note = store.settings.breatheNote }
        .onChange(of: note) { _, new in
            if new != store.settings.breatheNote { store.setBreatheNote(new) }
        }
        .onChange(of: focused) { _, focused in
            guard !focused else { return }
            note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            store.flush()
        }
        .onChange(of: store.settings.breatheNote) { _, new in
            // A line that arrives from the cloud, unless it's being written here.
            if !focused && new != note { note = new }
        }
    }
}
