import AuthenticationServices
import SwiftUI

/// Ajustes › Copia de seguridad: the cloud.
struct BackupPage: View {
    @Environment(AppStore.self) private var store
    @Environment(CloudSync.self) private var cloud
    @Environment(\.webAuthenticationSession) private var webAuth
    @State private var askingSignOut = false

    var body: some View {
        CardList {
            cloudSection
        }
        .navigationTitle("Copia de seguridad")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("¿Cerrar sesión?", isPresented: $askingSignOut, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) { cloud.signOut() }
        } message: {
            Text("Tus registros se quedan en este aparato, pero dejan de guardarse en la nube.")
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
                    .foregroundStyle(.warn)
                    .cardRow()
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
                .cardRow()
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
