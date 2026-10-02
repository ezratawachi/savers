import SwiftUI

/// Write: three fields that save while you write, and Done to check it off.
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
                Button("Done", action: onDone)
                    .buttonStyle(PrimaryButton())
                    .accessibilityLabel("Done, check off \(Letter.escritura.name)")
            }
        }
    }
}
