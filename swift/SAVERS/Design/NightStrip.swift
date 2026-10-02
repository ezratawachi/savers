import SwiftUI

/// The night under the clock, so content never scrolls under it. Once a tab's own title has scrolled
/// away, it shows it small, so you still know where you are.
struct NightStrip: View {
    var title: String?

    var body: some View {
        ZStack {
            if let title {
                Text(title)
                    .font(.display(17, relativeTo: .headline, weight: .bold))
                    .foregroundStyle(.ink)
                    .lineLimit(1)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .offset(y: 6)))
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .frame(maxWidth: .infinity)
        .environment(\.colorScheme, .dark)
        .background { Color.night.ignoresSafeArea() }
        .animation(.easeOut(duration: 0.2), value: title)
    }
}
