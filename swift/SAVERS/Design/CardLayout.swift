import SwiftUI

/// One set of measures for every card in the app, so they all read the same.
enum CardLayout {
    /// Room inside every card, on all four sides. Everything in a card's body lines up on it.
    static let inset: CGFloat = 14
    /// A card's corners.
    static let radius: CGFloat = 16
    /// Corners of a box inside a card: a field, a timer, a figure.
    static let innerRadius: CGFloat = 12
    /// How far a 44-pt target reaches past the 36-pt circle drawn in it, so the circle, not its target,
    /// sits on the card's line.
    static let circleSlack: CGFloat = 4
    /// The least a row in a card is tall: a 44-pt target and a little air.
    static let rowHeight: CGFloat = 50
    /// Where a letter card's title starts, past its circle.
    static let titleIndent: CGFloat = 44 - circleSlack + 10
}
