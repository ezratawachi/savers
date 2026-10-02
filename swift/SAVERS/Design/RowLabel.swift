import SwiftUI

/// "Afirmaciones ··· 3 frases ›": a row that opens a page.
struct RowLabel: View {
    let title: String
    var value: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .foregroundStyle(.ink)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .foregroundStyle(.muted)
                    .multilineTextAlignment(.trailing)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.muted)
                .opacity(0.6)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}
