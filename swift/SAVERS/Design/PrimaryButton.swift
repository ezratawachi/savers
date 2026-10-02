import SwiftUI

/// The filled button: "Empezar mi amanecer", "Listo".
struct PrimaryButton: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.reading(17).bold())
            // On the night, sky is light: its words go in the night's own blue.
            .foregroundStyle(colorScheme == .dark ? Color.night : .white)
            .padding(.horizontal, 20)
            .frame(minHeight: 48)
            .background(.sky, in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Motion.spring, value: configuration.isPressed)
    }
}
