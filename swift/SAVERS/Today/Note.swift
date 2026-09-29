import SwiftUI

/// A quiet line under a card's content.
struct Note: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.reading(15, relativeTo: .subheadline))
            .foregroundStyle(.muted)
    }
}
