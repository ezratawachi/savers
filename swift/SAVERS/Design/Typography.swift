import SwiftUI

/// Bricolage Grotesque for titles and numbers, Atkinson Hyperlegible for reading. Both follow Dynamic Type.
extension Font {
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .title, weight: Font.Weight = .heavy) -> Font {
        .custom("Bricolage Grotesque", size: size, relativeTo: style).weight(weight)
    }

    static func reading(_ size: CGFloat = 17, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Atkinson Hyperlegible", size: size, relativeTo: style)
    }
}
