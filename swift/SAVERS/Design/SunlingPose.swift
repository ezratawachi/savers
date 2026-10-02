import Foundation

/// How Sunling sits on the horizon: how far up he is and where his eyelids are. Only these change;
/// he never smiles. Lids are in the icon's units (a 1024 square), the bottom edge of each lid.
nonisolated struct SunlingPose: Equatable, Sendable {
    /// 1 shows the whole half disc, as in the icon; less sinks him behind the horizon.
    var rise: Double
    var leftLid: Double
    var rightLid: Double
    /// The dark line along each lid: drawn while his eyes are heavy, gone once he's awake.
    var lidLine: Double

    /// The icon itself: up, half asleep, the right eye a little more open.
    static let icon = SunlingPose(rise: 1, leftLid: 580, rightLid: 564, lidLine: 1)

    /// Shabbat and a day off: eyes shut, lower behind the horizon.
    static let asleep = SunlingPose(rise: 0.74, leftLid: 610, rightLid: 608, lidLine: 1)

    /// The morning, letter by letter: asleep and almost hidden at 0, up and awake (but calm, the lids
    /// still cut his eyes) at 6. The right eye leads, most at 2, as in the icon; less as both open.
    static func morning(_ done: Int) -> SunlingPose {
        let k = min(6, max(0, done))
        let rise = [0.68, 0.74, 0.8, 0.85, 0.9, 0.95, 1.0][k]
        let left = [604.0, 594, 584, 574, 564, 554, 542][k]
        let lead = [4.0, 10, 14, 12, 8, 6, 4][k]
        let line = [1.0, 1, 1, 1, 0.55, 0.25, 0][k]
        return SunlingPose(rise: rise, leftLid: left, rightLid: left - lead, lidLine: line)
    }
}
