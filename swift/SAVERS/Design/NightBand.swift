import SwiftUI

/// The top of each tab: the icon's night from edge to edge, closed by its golden horizon. What's on it is
/// your mornings (today, a month, your week); the day under it is for reading and doing. Always the
/// night's own colors, whatever the iPhone's mode.
struct NightBand<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.colorScheme, .dark)
            // Past the top too, so pulling down never shows the day above it.
            .background {
                Color.night.padding(.top, -1000)
            }
            .overlay(alignment: .bottom) {
                Color.horizon.frame(height: 1.5)
            }
    }
}
