import SwiftUI

/// Historial arrives in session 4 of the move to Swift.
struct HistoryPlaceholder: View {
    var body: some View {
        ContentUnavailableView("Historial", systemImage: "calendar", description: Text("El calendario y tus registros llegan pronto."))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.bg)
    }
}
