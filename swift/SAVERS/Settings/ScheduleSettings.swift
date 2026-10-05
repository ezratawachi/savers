import SwiftUI

/// Settings › Schedule: what each weekday is, and your kinds of day, each with a page of its own. Changes as you
/// tap, like iOS Settings.
struct ScheduleSettings: View {
    @Environment(AppStore.self) private var store
    @State private var adding = false
    /// A kind just made, until its sheet closes.
    @State private var made: String?
    /// Its page, open.
    @State private var opened: String?

    var body: some View {
        let r = store.routine

        CardList {
            Section {
                ForEach(0..<7, id: \.self) { w in
                    LabeledContent(Weekday.names[w].capitalizedFirst) {
                        Picker(Weekday.names[w].capitalizedFirst, selection: Binding { r.weekType(w) } set: { store.setWeekType(w, $0) }) {
                            ForEach(r.types) { Text($0.name).tag($0) }
                        }
                        .labelsHidden()
                        .tint(.muted)
                        // Kinds are equal by id, so a renamed one wouldn't redraw the menu by itself.
                        .id(r.types.map(\.name))
                    }
                }
            } header: {
                Text("Your week")
            } footer: {
                Text("For a single day, like a holiday, tap it in Today or in History.")
            }

            Section {
                ForEach(r.types) { k in
                    NavigationLink {
                        KindPage(id: k.id)
                    } label: {
                        let ws = r.days(of: k)
                        RowLabel(title: k.name, value: ws.isEmpty ? String(localized: "no days") : Weekday.list(ws))
                    }
                    .cardRow()
                }
                Button {
                    adding = true
                } label: {
                    Label("New kind", systemImage: "plus")
                        .font(.reading().bold())
                        .foregroundStyle(.sky)
                }
                .cardRow()
            } header: {
                Text("Kinds of day")
            } footer: {
                Text("\(r.firstSunrise.name) goes first: it's the one a day uses when it needs a sunrise and has none, like a day of rest you do anyway.")
            }
        }
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $adding, onDismiss: {
            opened = made
            made = nil
        }) {
            NewKindSheet { made = $0 }
        }
        .navigationDestination(item: $opened) { KindPage(id: $0) }
    }
}
