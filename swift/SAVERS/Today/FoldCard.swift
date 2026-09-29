import SwiftUI

/// Everything done, folded into one row: "Mañana · 5 hechas". Opens to show them again.
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
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.dawn, in: .circle)
                        .frame(width: 44, height: 44)
                    Text("\(Text(label).bold()) \(Text("· \(count) hechas").foregroundStyle(.muted))")
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
            .accessibilityHint(isOpen ? "Oculta lo hecho" : "Muestra lo hecho")
            if isOpen {
                content
                    .padding(.top, 4)
                    .transition(.opacity)
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surface)
                .stroke(Color.line, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: 16))
    }
}
