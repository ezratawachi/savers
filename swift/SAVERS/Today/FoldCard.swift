import SwiftUI

/// Everything done, folded into one row: "Morning · 5 done". Opens to show them again.
struct FoldCard<Content: View>: View {
    let label: String
    let count: Int
    @Binding var isOpen: Bool
    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Motion.pick(Motion.height, reduce: reduceMotion)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.onDone)
                        .frame(width: 36, height: 36)
                        .background(.done, in: .circle)
                        .frame(width: 44, height: 44)
                    Text("\(Text(label).bold()) \(Text("· \(count) done").foregroundStyle(.muted))")
                        .font(.reading(18, relativeTo: .headline))
                        .foregroundStyle(.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.muted)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            // The circle's drawing, not its target, sits on the card's line.
            .padding(EdgeInsets(top: -CardLayout.circleSlack, leading: -CardLayout.circleSlack,
                                bottom: -CardLayout.circleSlack, trailing: 0))
            .accessibilityHint(isOpen ? "Hides what's done" : "Shows what's done")
            if isOpen {
                content
                    .padding(.top, CardLayout.inset)
                    .transition(.opacity)
            }
        }
        .padding(CardLayout.inset)
        .background {
            RoundedRectangle(cornerRadius: CardLayout.radius)
                .fill(Color.surface)
                .stroke(Color.line, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: CardLayout.radius))
    }
}
