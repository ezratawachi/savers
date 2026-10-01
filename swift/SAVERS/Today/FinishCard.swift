import SwiftUI

/// "Mañana lista" with what's left for later, or "Día completo" with the streak.
struct FinishCard: View {
    let finish: Finish
    /// "Lectura a las 8:50 pm"
    let pending: String
    let streak: Int

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(.dawn, in: .circle)
                .accessibilityHidden(true)
            Text(finish == .morning ? "Mañana lista" : "Día completo")
                .font(.display(26, relativeTo: .title))
                .foregroundStyle(.ink)
                .accessibilityAddTraits(.isHeader)
            Group {
                if finish == .morning {
                    Text("Falta \(Text(pending).bold())")
                } else {
                    Text("Racha: \(Text(streak == 1 ? "1 día" : "\(streak) días").bold())")
                }
            }
            .font(.reading())
            .foregroundStyle(.ink)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(CardLayout.inset)
        .background(.dawnSoft, in: .rect(cornerRadius: CardLayout.radius))
        .accessibilityElement(children: .contain)
    }
}
