import SwiftUI

/// Afirmaciones: the phrases to say out loud.
struct AffirmationsBody: View {
    let items: [Item]
    let reviewDue: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if items.isEmpty {
                Text("Todavía no tienes afirmaciones.")
            } else {
                ForEach(items.indices, id: \.self) { i in
                    Text(items[i].text)
                        .font(.reading(19, relativeTo: .body))
                        .lineSpacing(3)
                }
                Note(reviewDue ? "Mes nuevo: ¿siguen sintiéndose tuyas?" : "Despacio, sintiendo cada frase.")
            }
        }
        .font(.reading())
        .foregroundStyle(.ink)
    }
}
