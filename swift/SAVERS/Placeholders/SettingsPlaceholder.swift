import AuthenticationServices
import SwiftUI

/// Ajustes arrives in session 4; for now: the cloud and bringing a copy in.
struct SettingsPlaceholder: View {
    @Environment(CloudSync.self) private var cloud
    @Environment(\.webAuthenticationSession) private var webAuth
    @State private var importing = false
    @State private var askingSignOut = false
    @State private var keepMusic = ToneEngine.keepMusic
    private var gemini: GeminiVoice { .shared }

    var body: some View {
        NavigationStack {
            List {
                soundSection
                cloudSection
                Section {
                    Button("Importar copia") { importing = true }
                        .foregroundStyle(.sky)
                } header: {
                    Text("Copia en archivo")
                } footer: {
                    Text(cloud.linked ? "Tus registros se guardan en este aparato y en la nube." : "Tus registros viven solo en este aparato.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(.bg)
            .navigationTitle("Ajustes")
        }
        .backupImporter(isPresented: $importing)
        .confirmationDialog("¿Cerrar sesión?", isPresented: $askingSignOut, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) { cloud.signOut() }
        } message: {
            Text("Tus registros se quedan en este aparato, pero dejan de guardarse en la nube.")
        }
    }

    private var soundSection: some View {
        Section {
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
    }

    @ViewBuilder
    private var cloudSection: some View {
        if cloud.linked {
            Section {
                TimelineView(.periodic(from: .now, by: 30)) { t in
                    LabeledContent("Estado") {
                        Text(cloud.statusLabel(now: t.date))
                            .foregroundStyle(cloud.error.isEmpty ? Color.muted : Color.warn)
                    }
                }
                if let email = cloud.email, !email.isEmpty {
                    LabeledContent("Cuenta", value: email)
                }
                Button("Cerrar sesión", role: .destructive) { askingSignOut = true }
            } header: {
                Text("Nube")
            } footer: {
                Text("Se guarda solo. Si cambias lo mismo en el iPhone y en la Mac, se queda el último cambio.")
            }
        } else {
            Section {
                Button {
                    Task { await cloud.signIn(using: webAuth) }
                } label: {
                    HStack {
                        Text("Entrar con Google").bold()
                        if cloud.busy { Spacer(); ProgressView() }
                    }
                }
                .foregroundStyle(.sky)
                .disabled(cloud.busy)
            } header: {
                Text("Nube")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if !cloud.error.isEmpty { Text(cloud.error).foregroundStyle(.warn) }
                    Text("Tus registros se guardan solos en la nube y los ves también en la Mac. Solo tu cuenta de Google puede abrirlos.")
                }
            }
        }
    }
}
