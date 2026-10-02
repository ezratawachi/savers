import SwiftUI

/// "Mañana lista" with what's left for later, or "Día completo" with the streak. No check of its own:
/// Sunling, up and awake on the horizon just above, is the finish.
struct FinishCard: View {
    let finish: Finish
    /// "Lee a las 8:50 pm"
    let pending: String
    let streak: Int

    var body: some View {
        VStack(spacing: 4) {
            Text(finish == .morning ? "Mañana lista" : "Día completo")
                .font(.display(26, relativeTo: .title))
                .foregroundStyle(.ink)
                .accessibilityAddTraits(.isHeader)
            Group {
                if finish == .morning {
                    Text("Falta \(Text(pending).bold())")
                } else {
                    Text("Racha: \(Text(streak == 1 ? "1 amanecer" : "\(streak) amaneceres").bold())")
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
