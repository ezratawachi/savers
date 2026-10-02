import SwiftUI

/// A step's first-time note, inside its card: what you do, why, and "Learn more". It goes once the step is
/// checked off for the first time, and comes back with the ⓘ.
struct StepNote: View {
    let letter: Letter
    let onMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(letter.how)
                .foregroundStyle(.ink)
            Text(letter.why)
                .foregroundStyle(.muted)
            Button("Learn more", action: onMore)
                .font(.reading(15, relativeTo: .subheadline).bold())
                .foregroundStyle(.sky)
                .buttonStyle(.borderless)
                .frame(minHeight: 32)
                .accessibilityHint("Opens The method")
        }
        .font(.reading(15, relativeTo: .subheadline))
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, CardLayout.inset)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(.surface2, in: .rect(cornerRadius: CardLayout.innerRadius))
    }
}
