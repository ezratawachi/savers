import SwiftUI

/// One letter of the guide. Pending: a card. Now: a sky edge and the sun. Done: a quiet row.
struct LetterCard<Content: View>: View {
    let letter: Letter
    let info: LetterInfo
    let done: Bool
    let isNow: Bool
    let isOpen: Bool
    /// When the letter should start and how long it lasts, for the sun; nil hides it.
    let sun: (start: Int, length: Int)?
    let sunNext: String
    let onToggle: () -> Void
    let onOpen: () -> Void
    /// Inside another card ("hechas"): no card of its own, on that card's line.
    var nested = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                CheckCircle(letter: letter, done: done, isNow: isNow, action: onToggle)
                if info.opens {
                    Button(action: onOpen) { rowText }
                        .buttonStyle(.plain)
                        .accessibilityHint(isOpen ? "Cierra la carta" : "Abre la carta")
                } else {
                    rowText
                }
            }
            // The circle's drawing, not its target, sits on the card's line.
            .padding(EdgeInsets(top: -CardLayout.circleSlack, leading: -CardLayout.circleSlack,
                                bottom: -CardLayout.circleSlack, trailing: 0))
            if let sun, isNow, !done {
                SunLine(start: sun.start, length: sun.length, next: sunNext)
                    .padding(.leading, CardLayout.titleIndent)
                    .padding(.top, 6)
                    .transition(.opacity)
            }
            if isOpen {
                content
                    .padding(.top, CardLayout.inset)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, nested ? 0 : CardLayout.inset)
        // Without a card around it: just room for the circle's target.
        .padding(.vertical, bare ? CardLayout.circleSlack : CardLayout.inset)
        .background {
            RoundedRectangle(cornerRadius: CardLayout.radius)
                .fill(Color.surface)
                .stroke(isNow ? Color.sky : Color.line, lineWidth: isNow ? 1.5 : 1)
                .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                .opacity(bare ? 0 : 1)
        }
        // Nested, the circle's target reaches past the edge; don't cut its drawing.
        .clipShape(.rect(cornerRadius: CardLayout.radius).inset(by: nested ? -CardLayout.circleSlack : 0))
    }

    /// No card drawn: a done row that's closed, or any letter inside another card.
    private var bare: Bool { nested || (done && !isOpen) }

    private var rowText: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(letter.name)
                        .font(.reading(18, relativeTo: .headline).bold())
                        .foregroundStyle(.ink)
                    if isNow && !done {
                        Text("Ahora")
                            .font(.reading(12, relativeTo: .caption).bold())
                            .foregroundStyle(.sky)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.sky.opacity(0.12), in: .capsule)
                            .transition(.opacity)
                    }
                }
                if !done {
                    Text(info.subtitle)
                        .font(.reading(15, relativeTo: .subheadline))
                        .foregroundStyle(.muted)
                }
            }
            .opacity(done ? 0.5 : 1)
            Spacer(minLength: 4)
            if !done {
                Text(info.time)
                    .font(.reading(15, relativeTo: .subheadline))
                    .monospacedDigit()
                    .foregroundStyle(.muted)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.muted)
                .rotationEffect(.degrees(isOpen ? 90 : 0))
                .opacity(info.opens ? 0.7 : 0)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 44)
        .contentShape(.rect)
    }
}
