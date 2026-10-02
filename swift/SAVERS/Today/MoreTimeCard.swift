import SwiftUI

/// Once, after the seventh complete sunrise of a 10- or 20-minute one: Sunling asks if you want more time.
struct MoreTimeCard: View {
    let done: Int
    let longer: SunriseLength
    let onAnswer: (_ yes: Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Want more time?")
                .font(.display(22, relativeTo: .title2, weight: .bold))
                .foregroundStyle(.ink)
                .accessibilityAddTraits(.isHeader)
            Text("\(done) sunrises done. If you like, each step can last a little longer: \(longer.rawValue) minutes in all.")
                .font(.reading())
                .foregroundStyle(.muted)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { buttons }
                VStack(alignment: .leading, spacing: 4) { buttons }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CardLayout.inset)
        .background {
            RoundedRectangle(cornerRadius: CardLayout.radius)
                .fill(Color.surface)
                .stroke(Color.line, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var buttons: some View {
        Button("Yes, \(longer.label)") { onAnswer(true) }
            .buttonStyle(PrimaryButton())
        Button("Not now") { onAnswer(false) }
            .font(.reading(16).bold())
            .foregroundStyle(.sky)
            .buttonStyle(.borderless)
            .frame(minHeight: 44)
    }
}
