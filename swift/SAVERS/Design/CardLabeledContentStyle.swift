import SwiftUI

/// "Afirmaciones ··· 3 frases": the name on the left, its value quiet on the right.
struct CardLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.label
                .foregroundStyle(.ink)
            Spacer(minLength: 8)
            configuration.content
                .foregroundStyle(.muted)
                .multilineTextAlignment(.trailing)
        }
    }
}
