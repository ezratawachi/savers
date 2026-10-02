import SwiftUI

/// "Morning done" with what's left for later, or "Day complete" with the streak. No check of its own:
/// Sunling, up and awake on the horizon just above, is the finish.
struct FinishCard: View {
    let finish: Finish
    /// "Read at 8:50 pm"
    let pending: String
    let streak: Int

    var body: some View {
        VStack(spacing: 4) {
            Text(finish == .morning ? "Morning done" : "Day complete")
                .font(.display(26, relativeTo: .title))
                .foregroundStyle(.ink)
                .accessibilityAddTraits(.isHeader)
            Group {
                if finish == .morning {
                    Text("Still to go: \(Text(pending).bold())")
                } else {
                    Text("Streak: \(Text(String(localized: "\(streak) sunrises")).bold())")
                }
            }
            .font(.reading())
            .foregroundStyle(.ink)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(CardLayout.inset)
        .background(.doneSoft, in: .rect(cornerRadius: CardLayout.radius))
        .accessibilityElement(children: .contain)
    }
}
