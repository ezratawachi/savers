import SwiftUI

/// A half sun behind the bottom edge of its rect, risen by `rise` (0 hidden, 1 the whole half disc).
/// Draw it in a rect twice as wide as tall.
nonisolated struct SunDisc: Shape {
    var rise: Double

    var animatableData: Double {
        get { rise }
        set { rise = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let r = rect.width / 2
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY + r * (1 - rise)), radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        p.closeSubpath()
        return p.intersection(Path(rect))
    }
}
