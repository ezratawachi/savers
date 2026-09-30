import AuthenticationServices
import SwiftUI

/// Ajustes › Copia de seguridad: the cloud, and a copy in a file.
struct BackupPage: View {
    @Environment(AppStore.self) private var store
    @Environment(CloudSync.self) private var cloud
    @Environment(\.webAuthenticationSession) private var webAuth
    @State private var importing = false
    @State private var exporting = false
    @State private var askingSignOut = false

    var body: some View {
        AppList {
            cloudSection
            fileSection
        }
        .navigationTitle("Copia de seguridad")
        .navigationBarTitleDisplayMode(.inline)
        .backupImporter(isPresented: $importing)
        .backupExporter(isPresented: $exporting)
        .confirmationDialog("¿Cerrar sesión?", isPresented: $askingSignOut, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) { cloud.signOut() }
        } message: {
            Text("Tus registros se quedan en este aparato, pero dejan de guardarse en la nube.")
        }
    }

    private var fileSection: some View {
        Section {
            LabeledContent("Última copia") {
                Text(lastCopy)
                    .foregroundStyle(store.backupOverdue(cloudLinked: cloud.linked) ? Color.warn : Color.muted)
            }
            Button("Exportar copia") { exporting = true }
                .foregroundStyle(.sky)
                .fontWeight(cloud.linked ? .regular : .bold)
            Button("Importar copia") { importing = true }
                .foregroundStyle(.sky)
        } header: {
            Text("Copia en archivo")
        } footer: {
            Text(cloud.linked
                 ? "Un JSON con todo, para guardarlo en Archivos o dárselo a una IA."
                 : "Tus registros viven solo en este aparato. Exporta una copia de vez en cuando y guárdala en Archivos o iCloud.")
        }
    }

    /// "29 de septiembre de 2026 (hoy)" or "Nunca".
    private var lastCopy: String {
        guard let last = store.lastExport else { return "Nunca" }
        let date = last.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "es")))
        return "\(date) (\(Self.ageLabel(store.backupAge).lowercased()))"
    }

    /// "Hoy", "Ayer", "Hace 5 días"
    static func ageLabel(_ days: Int) -> String {
        days == 0 ? "Hoy" : days == 1 ? "Ayer" : "Hace \(days) días"
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
