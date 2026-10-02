import SwiftUI

/// Ajustes › Notificaciones: one switch per notice, only on this iPhone. The first one turned on asks iOS.
struct NoticesSettings: View {
    @Environment(Notices.self) private var notices
    @Environment(AppStore.self) private var store
    @Environment(Runs.self) private var runs
    @Environment(Toast.self) private var toast
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        let blocked = notices.permission == .blocked
        CardList {
            Section {
                ForEach(NoteKind.allCases) { kind in
                    Toggle(isOn: Binding {
                        notices.isOn(kind) || notices.busy == kind
                    } set: { on in
                        Task {
                            await notices.turn(kind, on: on)
                            if kind == .lectura { runs.readingNoteChanged() }
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.name)
                            Text(kind.about(store.routine)).font(.footnote).foregroundStyle(.muted)
                        }
                    }
                    .tint(.sky)
                    .disabled(blocked || notices.busy != nil)
                }
            } footer: {
                Text("Nada desde el viernes en la tarde hasta que termina Shabbat.")
            }

            if blocked {
                Section {
                    Button("Abrir Configuración") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }
                    .foregroundStyle(.sky)
                    .cardRow()
                } header: {
                    Text("Los avisos están bloqueados. Actívalos en Configuración › Notificaciones › Sunling.")
                        .textCase(nil)
                        .font(.footnote)
                        .foregroundStyle(.warn)
                }
            } else if notices.anyOn {
                Section {
                    Button("Mandar un aviso de prueba") {
                        Task {
                            await notices.test()
                            toast.show("Aviso de prueba enviado")
                        }
                    }
                    .foregroundStyle(.sky)
                    .cardRow()
                } footer: {
                    Text("Cómo se ven y si suenan lo eliges en Configuración › Notificaciones › Sunling. Con el modo Dormir u otra concentración llegan sin sonido y sin mostrarse, salvo que Sunling esté entre sus apps permitidas.")
                }
            }
        }
        .navigationTitle("Notificaciones")
        .navigationBarTitleDisplayMode(.inline)
        .task { await notices.readPermission() }
        .onChange(of: scenePhase) { _, phase in
            // Back from Configuración: what you chose there shows here right away.
            if phase == .active { Task { await notices.readPermission() } }
        }
    }
}
