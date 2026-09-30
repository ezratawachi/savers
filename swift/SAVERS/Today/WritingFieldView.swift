import SwiftUI

/// One field. Filled and not being edited, it reads as text with "✓ Guardado"; empty or editing, three lines.
struct WritingFieldView: View {
    @Environment(AppStore.self) private var store
    let ds: String
    let field: WritingField
    let hint: String
    var focus: FocusState<WritingField?>.Binding

    @State private var text = ""
    @State private var loaded = false

    private var editing: Bool { focus.wrappedValue == field }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Text(field.label).bold()) \(Text(hint).foregroundStyle(.muted))")
                    .font(.reading(15, relativeTo: .subheadline))
                    .foregroundStyle(.ink)
                Spacer(minLength: 8)
                if !text.isEmpty && !editing {
                    Text("✓ Guardado")
                        .font(.reading(13, relativeTo: .caption))
                        .foregroundStyle(.ok)
                        .accessibilityHidden(true)
                }
            }
            TextField(field.label, text: $text, axis: .vertical)
                .font(.reading())
                .foregroundStyle(.ink)
                .lineLimit(text.isEmpty || editing ? 3... : 1...)
                .focused(focus, equals: field)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.surface2.opacity(editing || text.isEmpty ? 1 : 0.5), in: .rect(cornerRadius: CardLayout.innerRadius))
                .accessibilityLabel("\(field.label), \(hint)")
        }
        .onAppear {
            guard !loaded else { return }
            text = store.routine.day(ds)[field]
            loaded = true
        }
        .onChange(of: text) { _, new in
            store.setText(field, new, on: ds)
        }
        // What the Mac wrote comes in while the card is open, unless you're writing in this field.
        .onChange(of: store.routine.day(ds)[field]) { _, saved in
            if !editing && saved != text { text = saved }
        }
        .onChange(of: editing) { _, now in
            if !now { store.flush() }
        }
    }
}
