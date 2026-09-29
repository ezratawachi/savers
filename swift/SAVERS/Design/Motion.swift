import SwiftUI

/// The app's two movements: a critically damped spring, and heights that settle fast and land soft.
enum Motion {
    static let spring = Animation.spring(duration: 0.36, bounce: 0)
    static let height = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.32)

    /// No movement with "Reducir movimiento".
    static func pick(_ animation: Animation, reduce: Bool) -> Animation? { reduce ? nil : animation }
}
