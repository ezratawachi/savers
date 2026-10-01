import SwiftUI

/// Ajustes › Voz: pick a Gemini voice, try it, paste the key. Changes apply as you tap, like iOS Settings.
struct VoiceSettings: View {
    @Environment(Toast.self) private var toast
    @State private var gemini = GeminiVoice.shared
    @State private var keyText = GeminiVoice.shared.key
    @State private var trying: String?
    @FocusState private var keyFocused: Bool

    var body: some View {
        AppList {
            Section {
                ForEach(GeminiVoice.voices) { v in
                    row(v)
                }
            } header: {
                Text("Voz de Gemini")
            } footer: {
                Text("Probar lee tu primera pregunta de visualización. La visualización suena calmada, el ejercicio con energía y los avisos en tono neutro.")
            }
            Section {
                LabeledContent("Clave") {
                    SecureField("Pégala aquí", text: $keyText)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($keyFocused)
                        .submitLabel(.done)
                        .onSubmit { gemini.setKey(keyText) }
                }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(gemini.statusText)
                        .foregroundStyle(gemini.statusIsWarning ? Color.warn : Color.muted)
                    Text("Sácala gratis en aistudio.google.com con Get API key. Se queda solo en este iPhone: no va a la nube. Sin internet o sin límite, suena la voz del iPhone.")
                }
            }
        }
        .navigationTitle("Voz")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: keyFocused) { _, focused in if !focused { gemini.setKey(keyText) } }
        .onDisappear { gemini.setKey(keyText) }
    }

    private func row(_ v: GeminiVoice.Choice) -> some View {
        let on = gemini.hasKey && v.id == gemini.voice
        let soon = gemini.hasKey && v.id == gemini.nextVoice
        return HStack(spacing: 12) {
            Button {
                guard gemini.hasKey else { askKey(); return }
                gemini.choose(v.id)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(v.id).font(.reading().bold()).foregroundStyle(.ink)
                        Text(v.desc + (soon ? " · preparando" : ""))
                            .font(.reading(15, relativeTo: .subheadline))
                            .foregroundStyle(.muted)
                    }
                    Spacer()
                    if on {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.sky)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(on ? .isSelected : [])
            Button(trying == v.id ? "Creando…" : "Probar") { tryVoice(v.id) }
                .buttonStyle(.bordered)
                .tint(.sky)
                .disabled(trying != nil)
        }
    }

    private func askKey() {
        toast.show("Primero pega tu clave de Gemini")
        keyFocused = true
    }

    private func tryVoice(_ id: String) {
        gemini.setKey(keyText)
        guard gemini.hasKey else { askKey(); return }
        trying = id
        Task {
            if let problem = await gemini.tryVoice(id) { toast.show(problem) }
            trying = nil
        }
    }
}
