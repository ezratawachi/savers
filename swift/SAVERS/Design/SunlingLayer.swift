import SwiftUI

/// One layer of Sunling, drawn with the icon's own paths (`Resources/AppIcon.icon/Assets`) in its 1024
/// units. The view shows the strip from y 200 to the horizon at 770. Rise and lids animate.
nonisolated struct SunlingLayer: Shape {
    enum Part {
        case haloOuter, haloInner, body, pupils, lids, lidLines, beak
    }

    let part: Part
    var pose: SunlingPose

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(pose.rise, AnimatablePair(pose.leftLid, pose.rightLid)) }
        set {
            pose.rise = newValue.first
            pose.leftLid = newValue.second.first
            pose.rightLid = newValue.second.second
        }
    }

    /// The horizon, and the top of the strip the view shows.
    static let horizon = 770.0
    static let top = 200.0
    static let aspect = 1024 / (horizon - top)

    func path(in rect: CGRect) -> Path {
        let s = rect.width / 1024
        let toView = CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: s, y: s)
            .translatedBy(x: 0, y: -Self.top)
        return units.applying(toView)
    }

    /// The path in the icon's units. Everything but the halo sinks with the rise.
    private var units: Path {
        let sink = 410 * (1 - pose.rise)
        let down = CGAffineTransform(translationX: 0, y: sink)
        switch part {
        case .haloOuter:
            return halfDisc(radius: 560)
        case .haloInner:
            return halfDisc(radius: 485)
        case .body:
            var tufts = Path()
            tufts.move(to: CGPoint(x: 506, y: 396))
            tufts.addCurve(to: CGPoint(x: 552, y: 260), control1: CGPoint(x: 500, y: 334), control2: CGPoint(x: 514, y: 290))
            tufts.move(to: CGPoint(x: 532, y: 400))
            tufts.addCurve(to: CGPoint(x: 628, y: 300), control1: CGPoint(x: 548, y: 344), control2: CGPoint(x: 582, y: 310))
            // A union, so the stroke's outline and the disc don't cancel each other where they overlap.
            let p = halfDisc(radius: 410).union(tufts.strokedPath(StrokeStyle(lineWidth: 46, lineCap: .round)))
            return p.applying(down)
        case .pupils:
            var p = Path()
            p.addEllipse(in: CGRect(x: 330, y: 532, width: 100, height: 100))
            p.addEllipse(in: CGRect(x: 594, y: 532, width: 100, height: 100))
            return p.applying(down)
        case .lids:
            var p = Path()
            for (x, b) in eyes {
                p.move(to: CGPoint(x: x - 68, y: b - 88))
                p.addLine(to: CGPoint(x: x + 68, y: b - 88))
                p.addLine(to: CGPoint(x: x + 68, y: b))
                p.addQuadCurve(to: CGPoint(x: x - 68, y: b), control: CGPoint(x: x, y: b + 42))
                p.closeSubpath()
            }
            return p.applying(down)
        case .lidLines:
            var p = Path()
            for (x, b) in eyes {
                p.move(to: CGPoint(x: x - 64, y: b))
                p.addQuadCurve(to: CGPoint(x: x + 64, y: b), control: CGPoint(x: x, y: b + 42))
            }
            return p.strokedPath(StrokeStyle(lineWidth: 24, lineCap: .round)).applying(down)
        case .beak:
            var p = Path()
            p.move(to: CGPoint(x: 486, y: 636))
            p.addLine(to: CGPoint(x: 538, y: 636))
            p.addLine(to: CGPoint(x: 512, y: 676))
            p.closeSubpath()
            return p.union(p.strokedPath(StrokeStyle(lineWidth: 10, lineJoin: .round))).applying(down)
        }
    }

    /// Each eye's center and the bottom edge of its lid.
    private var eyes: [(Double, Double)] {
        [(380, pose.leftLid), (644, pose.rightLid)]
    }

    private func halfDisc(radius: Double) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: 512, y: Self.horizon), radius: radius,
                 startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        p.closeSubpath()
        return p
    }
}
