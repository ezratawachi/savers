import Observation
import SwiftUI

/// Where Hoy's horizon and Sunling are on screen, so the opening can land on them. Hoy reports them
/// until the opening is over. On a new install the welcome comes first, over the same night.
@Observable
final class Opening {
    var horizon: CGFloat?
    var bird: CGRect?
    var pose = SunlingPose.icon
    var lit = false
    var done = false
    /// The three welcome screens are showing; the opening waits for them.
    var welcoming: Bool
    /// How Sunling sits on the launch horizon before he lands: the icon, or waking up during the welcome.
    var startPose: SunlingPose

    init(welcoming: Bool = false) {
        self.welcoming = welcoming
        startPose = welcoming ? .asleep : .icon
    }
}
