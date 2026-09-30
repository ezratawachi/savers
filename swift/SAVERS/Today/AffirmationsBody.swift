import SwiftUI

/// Afirmaciones: the phrases to say out loud.
struct AffirmationsBody: View {
    let items: [Item]
    let reviewDue: Bool
    /// "Revisar afirmaciones" (the monthly review) or "Agregar afirmaciones" when there are none.
    let onEdit: (_ review: Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if items.isEmpty {
                Text("Todavía no tienes afirmaciones.")
                Button("Agregar afirmaciones") { onEdit(false) }
                    .buttonStyle(PrimaryButton())
            } else {
                ForEach(items.indices, id: \.self) { i in
                    Text(items[i].text)
                        .font(.reading(19, relativeTo: .body))
                        .lineSpacing(3)
                }
                Note(reviewDue ? "Mes nuevo: ¿siguen sintiéndose tuyas?" : "Despacio, sintiendo cada frase.")
                if reviewDue {
                    Button("Revisar afirmaciones") { onEdit(true) }
                        .buttonStyle(PrimaryButton())
                }
            }
        }
        .font(.reading())
        .foregroundStyle(.ink)
    }
}
