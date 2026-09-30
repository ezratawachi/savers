import SwiftUI

/// Ajustes: the name, the routine's content, sound, and the copy. Each screen pushes in from the right.
struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(CloudSync.self) private var cloud
    @Environment(Notices.self) private var notices
    @State private var name = ""
    @State private var keepMusic = ToneEngine.keepMusic
    @FocusState private var nameFocused: Bool
    private var gemini: GeminiVoice { .shared }

    private static let readApps = [("libros", "Libros"), ("kindle", "Kindle"), ("papel", "Libro físico")]

    var body: some View {
        let s = store.settings
        let r = store.routine
        NavigationStack {
            List {
                Section {
                    LabeledContent("Tu nombre") {
                        TextField("Para el saludo", text: $name)
                            .multilineTextAlignment(.trailing)
                            .textContentType(.givenName)
                            .submitLabel(.done)
                            .focused($nameFocused)
                    }
                }
                Section {
                    NavigationLink {
                        ScheduleSettings()
                    } label: {
                        LabeledContent("Horario", value: count(r.days(of: .normal).count + r.days(of: .gym).count, "día", "días"))
                    }
                    NavigationLink {
                        ItemsPage(kind: .affirmations)
                    } label: {
                        let n = s.affirmations.filled.count
                        LabeledContent("Afirmaciones", value: n > 0 ? count(n, "frase", "frases") : "Vacío")
                    }
                    NavigationLink {
                        ItemsPage(kind: .visualization)
                    } label: {
                        let n = s.visualization.items.filled.count
                        LabeledContent("Visualización", value: n > 0 ? count(n, "pregunta", "preguntas") : "Vacío")
                    }
                    Picker("Leer en", selection: Binding { s.readApp } set: { store.setReadApp($0) }) {
                        ForEach(Self.readApps, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    .tint(.muted)
                }
                Section {
                    NavigationLink {
                        NoticesSettings()
                    } label: {
                        LabeledContent("Notificaciones", value: notices.anyOn ? "Activadas" : "Apagadas")
                    }
                    NavigationLink {
                        VoiceSettings()
                    } label: {
                        LabeledContent("Voz", value: gemini.hasKey ? gemini.voice : "Del iPhone")
                    }
                    Toggle("Mantener mi música", isOn: $keepMusic)
                        .tint(.sky)
                        .onChange(of: keepMusic) { _, on in ToneEngine.keepMusic = on }
                } footer: {
                    Text("En los temporizadores tu música sigue sonando, pero la voz solo se oye si el iPhone no está en silencio. Apagado, la voz pausa tu música y suena siempre.")
                }
                Section {
                    NavigationLink {
                        BackupPage()
                    } label: {
                        LabeledContent("Copia de seguridad") {
                            Text(cloud.linked ? "En la nube" : store.lastExport == nil ? "Nunca" : BackupPage.ageLabel(store.backupAge))
                                .foregroundStyle(store.backupOverdue(cloudLinked: cloud.linked) ? Color.warn : Color.muted)
                        }
                    }
                } footer: {
                    Text(cloud.linked ? "Tus registros se guardan en este aparato y en la nube." : "Tus registros viven solo en este aparato.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(.bg)
            .navigationTitle("Ajustes")
        }
        .onAppear { name = store.settings.name }
        .onChange(of: name) { _, new in
            if new != store.settings.name { store.setName(new) }
        }
        .onChange(of: nameFocused) { _, focused in
            guard !focused else { return }
            name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            store.flush()
        }
        .onChange(of: store.settings.name) { _, new in
            // A name that arrives from the cloud, unless it's being written here.
            if !nameFocused && new != name { name = new }
        }
    }

    private func count(_ n: Int, _ one: String, _ many: String) -> String { "\(n) \(n == 1 ? one : many)" }
}
