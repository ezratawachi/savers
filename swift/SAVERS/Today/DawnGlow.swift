import SwiftUI

/// A faint dawn behind the top of Hoy while the morning is still to do: the greeting, without words.
/// Flat under the clock (where `band` covers the content), then fading into the background.
struct DawnGlow: View {
    /// 0 when off, so it fades in and out with the finish.
    let strength: Double

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .dawn.opacity(strength), location: 0.15),
                .init(color: .dawn.opacity(0), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 380)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// The strip under the clock: solid, so the content scrolling under it never shows through.
    static func band(_ strength: Double) -> some View {
        Color.bg
            .overlay(Color.dawn.opacity(strength))
            .ignoresSafeArea()
    }

    /// How strong it is when on. Quiet enough to be felt more than seen.
    static let on = 0.09
}
