import SwiftUI

/// Lectura: with your coffee, or later on a gym day.
struct ReadingBody: View {
    let minutes: Int
    let gym: Bool
    /// "8:50 pm" on a gym day, when the schedule says.
    let laterAt: String
    let gymReading: String?
    let done: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if gym {
                    Text(laterLine + " Empieza desde aquí y se marca sola.")
                } else {
                    Text("\(minutes) minutos con tu café. La meta es el tiempo, no las páginas.")
                }
            }
            .font(.reading())
            .foregroundStyle(.ink)
            ReadingTimer(done: done)
        }
    }

    private var laterLine: String {
        if !laterAt.isEmpty { return "Hoy lees más tarde, a las \(laterAt)." }
        if let g = gymReading, !g.isEmpty { return "Hoy lees más tarde: \(g)." }
        return "Hoy lees más tarde."
    }
}
