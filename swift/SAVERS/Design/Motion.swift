import SwiftUI

/// The app's movements: a critically damped spring, heights that settle fast and land soft, and Sunling's
/// slow rise, like the sun's.
enum Motion {
    static let spring = Animation.spring(duration: 0.36, bounce: 0)
    static let height = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.32)
    static let sun = Animation.spring(duration: 0.9, bounce: 0)

    /// No movement with "Reducir movimiento".
    static func pick(_ animation: Animation, reduce: Bool) -> Animation? { reduce ? nil : animation }
}
