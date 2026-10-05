import SwiftUI

/// Read: with your coffee, or in a block of its own ("Más tarde · 8:50 pm").
struct ReadingBody: View {
    let minutes: Int
    /// Where Read goes when it isn't in the sunrise.
    let placement: Placement?
    let done: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if let placement {
                    Text(line(placement) + " " + String(localized: "Start it here and it checks itself off."))
                } else {
                    Text("\(minutes) minutes with your coffee. The goal is the time, not the pages.")
                }
            }
            .font(.reading())
            .foregroundStyle(.ink)
            ReadingTimer(done: done)
        }
    }

    private func line(_ p: Placement) -> String {
        if p.time.isEmpty { return String(localized: "Today you read later.") }
        return p.isLater ? String(localized: "Today you read later, at \(p.time).") : String(localized: "Today you read at \(p.time).")
    }
}
