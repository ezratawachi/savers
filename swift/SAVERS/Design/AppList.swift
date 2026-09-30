import SwiftUI

/// A settings list in the app's colors: Hoy's background behind it, and rows the color of its cards.
/// (The system's gray rows show up against the night blue.)
struct AppList<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        List {
            Group { content }
                .listRowBackground(Color.surface)
        }
        .scrollContentBackground(.hidden)
        .background(.bg)
    }
}
