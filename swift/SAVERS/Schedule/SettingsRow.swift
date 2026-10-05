import SwiftUI

/// "Get up · 5:20 · Thu 5:10 ›"; a step under its block is indented.
struct SettingsRow: View {
    let title: String
    let detail: String
    var chevron = false
    var sub = false

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(sub ? .reading(16) : .reading().bold())
                .foregroundStyle(.ink)
                .padding(.leading, sub ? 16 : 0)
            Spacer(minLength: 8)
            Text(detail)
                .font(.reading(15, relativeTo: .subheadline))
                .monospacedDigit()
                .foregroundStyle(.muted)
                .multilineTextAlignment(.trailing)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.muted)
                .opacity(chevron ? 0.6 : 0)
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
