import SwiftUI

/// Escritura: three fields that save while you write, and Listo to mark the letter.
struct WritingBody: View {
    let ds: String
    let gym: Bool
    let done: Bool
    var focus: FocusState<WritingField?>.Binding
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(WritingField.allCases) { field in
                WritingFieldView(ds: ds, field: field, hint: field.hint(gym: gym), focus: focus)
                    .id(field)
            }
            if !done {
                Button("Listo", action: onDone)
                    .buttonStyle(PrimaryButton())
                    .accessibilityLabel("Listo, marcar Escritura")
            }
        }
    }
}
