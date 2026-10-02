import SwiftUI

/// A day without the routine: Shabbat, or a day of rest (with a way to do it anyway).
struct RestCard: View {
    let title: String
    let text: String
    var button: (label: String, action: () -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.display(26, relativeTo: .title))
                .foregroundStyle(.ink)
                .accessibilityAddTraits(.isHeader)
            Text(text)
                .font(.reading())
                .foregroundStyle(.muted)
            if let button {
                Button(button.label, action: button.action)
                    .buttonStyle(PrimaryButton())
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CardLayout.inset)
        .background {
            RoundedRectangle(cornerRadius: CardLayout.radius)
                .fill(Color.surface)
                .stroke(Color.line, lineWidth: 1)
        }
    }
}
