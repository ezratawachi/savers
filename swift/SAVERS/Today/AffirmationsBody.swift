import SwiftUI

/// Affirm: the phrases to say out loud.
struct AffirmationsBody: View {
    let items: [Item]
    let reviewDue: Bool
    /// "Review affirmations" (the monthly review) or "Add affirmations" when there are none.
    let onEdit: (_ review: Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if items.isEmpty {
                Text("You don't have any affirmations yet.")
                Button("Add affirmations") { onEdit(false) }
                    .buttonStyle(PrimaryButton())
            } else {
                ForEach(items.indices, id: \.self) { i in
                    Text(items[i].text)
                        .font(.reading(19, relativeTo: .body))
                        .lineSpacing(3)
                }
                Note(reviewDue ? String(localized: "New month: do they still feel like yours?") : String(localized: "Slowly, feeling each phrase."))
                if reviewDue {
                    Button("Review affirmations") { onEdit(true) }
                        .buttonStyle(PrimaryButton())
                }
            }
        }
        .font(.reading())
        .foregroundStyle(.ink)
    }
}
