import SwiftUI
import UniformTypeIdentifiers

/// "Importar": pick a copy file, see what it will change, then apply it.
struct BackupImporter: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(AppStore.self) private var store
    @Environment(Toast.self) private var toast
    @State private var pending: Backup?
    @State private var asking = false

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $isPresented, allowedContentTypes: [.json]) { result in
                guard case .success(let url) = result else { return }
                read(url)
            }
            .alert("¿Importar esta copia?", isPresented: $asking, presenting: pending) { backup in
                Button("Cancelar", role: .cancel) { pending = nil }
                Button("Importar") {
                    store.apply(backup)
                    toast.show(backup.doneMessage)
                    pending = nil
                }
            } message: { backup in
                Text(backup.summary)
            }
    }

    private func read(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            toast.show("No se pudo leer el archivo")
            return
        }
        do {
            pending = try Backup(data: data)
            asking = true
        } catch {
            toast.show(error.message)
        }
    }
}

extension View {
    func backupImporter(isPresented: Binding<Bool>) -> some View {
        modifier(BackupImporter(isPresented: isPresented))
    }
}
