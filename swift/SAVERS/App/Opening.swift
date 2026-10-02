import Observation
import SwiftUI

/// Where Hoy's horizon and Sunling are on screen, so the opening can land on them. Hoy reports them
/// until the opening is over.
@Observable
final class Opening {
    var horizon: CGFloat?
    var bird: CGRect?
    var pose = SunlingPose.icon
    var lit = false
    var done = false
}
