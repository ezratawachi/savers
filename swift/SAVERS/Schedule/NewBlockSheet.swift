import SwiftUI

/// A new block for a kind: its name, when in the day, and its hour. It's added where its hour puts it.
struct NewBlockSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let kind: DayType
    /// The block made, to open it next.
    let onAdd: (String) -> Void

    @State private var name = ""
    @State private var group = TypeSchedule.Group.steps
    @State private var time = ""
    @FocusState private var naming: Bool

    var body: some View {
        let title = name.trimmingCharacters(in: .whitespaces)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    CardSections {
                        Section("Name") {
                            TextField("Gym, Read at night, On the bus", text: $name)
                                .focused($naming)
                                .submitLabel(.done)
                                .accessibilityLabel("Name")
                        }
                    }
                    SegmentedChoice(
                        label: String(localized: "When"),
                        options: [
                            .init(id: .night, title: String(localized: "The night before")),
                            .init(id: .steps, title: String(localized: "In the morning")),
                            .init(id: .later, title: String(localized: "Later")),
                        ],
                        selection: $group
                    )
                    TimeWheel(label: String(localized: "Time"), time: time) { time = $0 }
                        .frame(maxWidth: .infinity)
                    Note(String(localized: "On every \(kind.name) day. Then you choose the steps it holds."))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(.bg)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let id = store.addBlock(kind, group: group, title: title, time: time) { onAdd(id) }
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .tint(.sky)
        .onAppear {
            time = usualTime(group)
            naming = true
        }
        .onChange(of: group) { _, g in time = usualTime(g) }
    }

    /// Where a new block starts: at the sunrise in the morning, in the evening for later and the night.
    private func usualTime(_ g: TypeSchedule.Group) -> String {
        switch g {
        case .night: "10:00 pm"
        case .later: "8:00 pm"
        case .steps:
            store.routine.settings.schedule?.type(kind)?.sunriseBlockID.flatMap { store.routine.step(kind, id: $0)?.time } ?? "6:00"
        }
    }
}
