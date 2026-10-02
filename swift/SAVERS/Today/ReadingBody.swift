import SwiftUI

/// Read: with your coffee, or later on a gym day.
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
                    Text(laterLine + " " + String(localized: "Start it here and it checks itself off."))
                } else {
                    Text("\(minutes) minutes with your coffee. The goal is the time, not the pages.")
                }
            }
            .font(.reading())
            .foregroundStyle(.ink)
            ReadingTimer(done: done)
        }
    }

    private var laterLine: String {
        if !laterAt.isEmpty { return String(localized: "Today you read later, at \(laterAt).") }
        if let g = gymReading, !g.isEmpty { return String(localized: "Today you read later: \(g).") }
        return String(localized: "Today you read later.")
    }
}
