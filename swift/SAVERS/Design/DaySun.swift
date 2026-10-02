import SwiftUI

/// A day as a little sun on its own horizon: it shows more with each letter, and a whole half sun on a
/// golden line is a complete morning. No face; Sunling is only where a whole day is shown.
struct DaySun: View {
    /// 0…1 of the half disc showing.
    var rise: Double
    /// The line lit in gold: the morning was complete.
    var lit = false
    /// Without a line: a day with no horizon at all.
    var line = true
    var diameter: CGFloat = 28

    var body: some View {
        VStack(spacing: 0) {
            SunDisc(rise: rise)
                .fill(Color.done)
                .frame(width: diameter, height: diameter / 2)
            Rectangle()
                .fill(lit ? Color.horizon : Color.nightLetter)
                .frame(height: 1.5)
                .opacity(line ? 1 : 0)
        }
        .accessibilityHidden(true)
    }

    /// How high the sun is for each number of letters: a few clear steps, so a sliver still reads.
    static func rise(_ done: Int) -> Double {
        [0, 0.32, 0.46, 0.6, 0.73, 0.86, 1][min(6, max(0, done))]
    }
}
