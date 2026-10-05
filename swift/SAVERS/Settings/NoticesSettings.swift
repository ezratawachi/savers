import SwiftUI

/// Settings › Notifications: one switch per notice, only on this iPhone. The first one turned on asks iOS.
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
            }

            if blocked {
                Section {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }
                    .foregroundStyle(.sky)
                    .cardRow()
                } header: {
                    Text("Notifications are blocked. Turn them on in Settings › Notifications › Sunling.")
                        .textCase(nil)
                        .font(.footnote)
                        .foregroundStyle(.warn)
                }
            } else if notices.anyOn {
                Section {
                    Button("Send a test notification") {
                        Task {
                            await notices.test()
                            toast.show(String(localized: "Test notification sent"))
                        }
                    }
                    .foregroundStyle(.sky)
                    .cardRow()
                } footer: {
                    Text("How they look and whether they make a sound, you choose in Settings › Notifications › Sunling. With Sleep or another Focus they arrive silently and hidden, unless Sunling is one of its allowed apps.")
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await notices.readPermission() }
        .onChange(of: scenePhase) { _, phase in
            // Back from iOS Settings: what you chose there shows here right away.
            if phase == .active { Task { await notices.readPermission() } }
        }
    }
}
