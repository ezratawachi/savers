import SwiftUI

/// The bird of the icon, sitting on a horizon: the view's bottom edge is the horizon. He only rises and
/// opens his eyes; his halo lights up once the morning is done. Always the icon's two colors.
struct Sunling: View {
    var pose: SunlingPose
    /// The halo lit: the morning is done.
    var lit = false

    var body: some View {
        ZStack {
            SunlingLayer(part: .haloOuter, pose: pose).fill(lit ? Self.litOuter : Self.haloOuter)
            SunlingLayer(part: .haloInner, pose: pose).fill(lit ? Self.litInner : Self.haloInner)
            ZStack {
                SunlingLayer(part: .body, pose: pose).fill(Self.amber)
                SunlingLayer(part: .pupils, pose: pose).fill(Self.night)
                SunlingLayer(part: .lids, pose: pose).fill(Self.amber)
                SunlingLayer(part: .lidLines, pose: pose).fill(Self.night).opacity(pose.lidLine)
                SunlingLayer(part: .beak, pose: pose).fill(Self.night)
            }
            // He sinks behind the horizon, not through it.
            .clipShape(.rect)
        }
        .aspectRatio(SunlingLayer.aspect, contentMode: .fit)
        .accessibilityHidden(true)
    }

    // The icon's colors, the same in both modes.
    private static let amber = Color(red: 0xF2 / 255, green: 0xB5 / 255, blue: 0x44 / 255)
    private static let night = Color(red: 0x1B / 255, green: 0x25 / 255, blue: 0x38 / 255)
    private static let haloOuter = Color(red: 0x21 / 255, green: 0x2D / 255, blue: 0x47 / 255)
    private static let haloInner = Color(red: 0x28 / 255, green: 0x37 / 255, blue: 0x53 / 255)
    private static let litOuter = Color(red: 0x2A / 255, green: 0x37 / 255, blue: 0x56 / 255)
    private static let litInner = Color(red: 0x36 / 255, green: 0x47 / 255, blue: 0x6A / 255)
}
