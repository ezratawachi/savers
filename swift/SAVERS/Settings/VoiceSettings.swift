import SwiftUI

/// Settings › Voice: pick a Gemini voice, try it, paste the key. Changes apply as you tap, like iOS Settings.
struct VoiceSettings: View {
    @Environment(Toast.self) private var toast
    @State private var gemini = GeminiVoice.shared
    @State private var keyText = GeminiVoice.shared.key
    @State private var trying: String?
    @FocusState private var keyFocused: Bool

    var body: some View {
        CardList {
            Section {
                ForEach(GeminiVoice.voices) { v in
                    row(v)
                }
            } header: {
                Text("Gemini voice")
            } footer: {
                Text("Try reads your first \(Letter.visualizacion.name) question. \(Letter.visualizacion.name) sounds calm, the home routine energetic and the notices neutral.")
            }
            Section {
                LabeledContent("Key") {
                    SecureField("Paste it here", text: $keyText)
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
                    Text("Get it free at aistudio.google.com with Get API key. It stays only on this iPhone: it never goes to the cloud. With no internet or no quota left, the iPhone's voice plays.")
                }
            }
        }
        .navigationTitle("Voice")
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
                        Text(v.desc + (soon ? " · " + String(localized: "preparing") : ""))
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
            Button(trying == v.id ? "Creating…" : "Try") { tryVoice(v.id) }
                .buttonStyle(.bordered)
                .tint(.sky)
                .disabled(trying != nil)
        }
    }

    private func askKey() {
        toast.show(String(localized: "First paste your Gemini key"))
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
