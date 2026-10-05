import SwiftUI

/// A new kind of day: its name, and whether it starts with just the sunrise, as a day of rest, or the same as
/// one you have.
struct NewKindSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// The kind made, to open its page.
    let onCreate: (String) -> Void

    @State private var name = ""
    @State private var start = Schedule.Start.sunrise
    @FocusState private var naming: Bool

    var body: some View {
        let r = store.routine
        let title = name.trimmingCharacters(in: .whitespaces)
        let taken = r.kind(named: title)

        NavigationStack {
            CardList {
                Section {
                    TextField("Name", text: $name)
                        .focused($naming)
                        .submitLabel(.done)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Name")
                } header: {
                    Text("Name")
                } footer: {
                    if let taken {
                        Text("You already have a kind called \(taken.name).")
                            .foregroundStyle(.warn)
                    }
                }
                Section("Start from") {
                    option(.sunrise, String(localized: "Just the sunrise"), String(localized: "One block with the six steps"))
                    option(.rest, String(localized: "A day of rest"), String(localized: "No hours"))
                    ForEach(r.types.filter(\.hasSunrise)) { k in
                        option(.copy(k.id), String(localized: "Same as \(k.name)"), String(localized: "Its blocks and hours"))
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: start)
            .navigationTitle("New kind")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(store.addKind(named: title, from: start))
                        dismiss()
                    }
                    .disabled(title.isEmpty || taken != nil)
                }
            }
        }
        .tint(.sky)
        .onAppear { naming = true }
    }

    private func option(_ s: Schedule.Start, _ title: String, _ note: String) -> some View {
        let on = s == start
        return Button {
            start = s
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.ink)
                    Text(note)
                        .font(.reading(15, relativeTo: .subheadline))
                        .foregroundStyle(.muted)
                }
                Spacer(minLength: 8)
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.sky)
                    .opacity(on ? 1 : 0)
                    .accessibilityHidden(true)
            }
        }
        .cardRow()
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
