import SwiftUI

/// "**5:50** · Sunrise" above a block's letters.
struct BlockHeader: View {
    let head: [String]
    /// Inside a card (the done ones), on that card's line.
    var nested = false

    var body: some View {
        let parts = head.filter { !$0.isEmpty }
        if let first = parts.first {
            let rest = parts.dropFirst().joined(separator: " · ")
            Text(rest.isEmpty ? "\(Text(first).bold())" : "\(Text(first).bold()) · \(rest)")
                .font(.reading(15, relativeTo: .subheadline))
                .foregroundStyle(.muted)
                .padding(.top, 10)
                .padding(.leading, nested ? 0 : 4)
                .accessibilityAddTraits(.isHeader)
        }
    }
}
