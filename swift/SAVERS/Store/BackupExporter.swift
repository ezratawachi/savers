import SwiftUI
import UniformTypeIdentifiers

/// "Exportar copia": saves `savers-copia-AAAA-MM-DD.json` where you choose (Archivos, iCloud Drive…).
struct BackupExporter: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(AppStore.self) private var store
    @Environment(Toast.self) private var toast
    @State private var file: BackupFile?

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, now in
                guard now else { return }
                guard let data = store.backupData() else {
                    isPresented = false
                    toast.show("No se pudo preparar la copia")
                    return
                }
                file = BackupFile(data: data)
            }
            .fileExporter(isPresented: Binding { isPresented && file != nil } set: { if !$0 { isPresented = false } },
                          document: file, contentType: .json, defaultFilename: "savers-copia-\(store.today).json") { result in
                file = nil
                isPresented = false
                if case .success = result {
                    store.markBackedUp()
                    toast.show("Copia exportada")
                }
            }
    }
}

struct BackupFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension View {
    func backupExporter(isPresented: Binding<Bool>) -> some View {
        modifier(BackupExporter(isPresented: isPresented))
    }
}
