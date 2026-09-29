import SwiftUI

/// A day without the routine: Shabbat, or a day without SAVERS (with a way to do them anyway).
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
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surface)
                .stroke(Color.line, lineWidth: 1)
        }
    }
}
