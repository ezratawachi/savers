import SwiftUI

/// Opening the app is a short dawn. The first frame is the launch screen (the icon, big: Sunling on a
/// horizon across the middle of the night); then the horizon rises to Hoy's, Sunling settles where Hoy
/// has him, the night under the horizon gives way to the day, and the curtain fades onto Hoy. Only when
/// the app starts.
struct OpeningCurtain: View {
    @Environment(Opening.self) private var opening
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false
    @State private var gone = false

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let h = g.size.height
            let start = startFrame(in: g.size)
            let horizon = landed ? (opening.horizon ?? h / 2) : h / 2
            let bird = landed ? (opening.bird ?? start) : start
            ZStack(alignment: .topLeading) {
                Color.night
                    .frame(width: w, height: horizon)
                Color.night
                    .frame(width: w, height: max(0, h - horizon))
                    .offset(y: horizon)
                    .opacity(landed ? 0 : 1)
                Color.horizon
                    .frame(width: w, height: 1.5)
                    .offset(y: horizon - 1.5)
                Sunling(pose: landed ? opening.pose : opening.startPose, lit: landed && opening.lit)
                    .frame(width: bird.width, height: bird.height)
                    .offset(x: bird.minX, y: bird.minY)
            }
        }
        .ignoresSafeArea()
        .compositingGroup()
        .opacity(gone ? 0 : 1)
        .allowsHitTesting(!gone)
        .accessibilityHidden(true)
        .animation(Motion.pick(Motion.sun, reduce: reduceMotion), value: opening.startPose)
        .task(id: opening.welcoming) {
            guard !opening.welcoming else { return }
            await play()
        }
    }

    /// Sunling as the launch image draws him: a 250-pt half disc, centered, on the screen's middle line.
    private func startFrame(in size: CGSize) -> CGRect {
        let width = 250 * 1024 / 820.0
        let height = width / SunlingLayer.aspect
        return CGRect(x: (size.width - width) / 2, y: size.height / 2 - height, width: width, height: height)
    }

    private func play() async {
        // A beat for Hoy to lay out and say where its horizon is.
        try? await Task.sleep(for: .milliseconds(120))
        if !reduceMotion && opening.bird != nil {
            withAnimation(.spring(duration: 0.8, bounce: 0)) { landed = true }
            // Fade only once he has landed on Hoy's Sunling, so nothing moves under the fade.
            try? await Task.sleep(for: .milliseconds(850))
        }
        withAnimation(.easeOut(duration: 0.25)) { gone = true }
        try? await Task.sleep(for: .milliseconds(250))
        opening.done = true
    }
}
