import SwiftUI

/// A button in a card: it dims while pressed, like Hoy's rows. A whole-row button pads itself so all
/// of the row is the target.
struct CardRowButtonStyle: ButtonStyle {
    var padded = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, padded ? 8 : 0)
            .frame(maxWidth: padded ? .infinity : nil, minHeight: padded ? CardLayout.rowHeight : nil, alignment: .leading)
            .padding(.horizontal, padded ? CardLayout.inset : 0)
            .contentShape(.rect)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .animation(.easeOut(duration: configuration.isPressed ? 0.05 : 0.2), value: configuration.isPressed)
    }
}
