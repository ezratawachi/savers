import SwiftUI

/// The six letters as one word: done in terracotta, the rest quiet. Not buttons.
struct HeroLetters: View {
    let day: Day
    let streak: Int
    let showStreak: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                ForEach(Letter.allCases) { letter in
                    Text(letter.initial)
                        .font(.display(60, relativeTo: .largeTitle, weight: .heavy))
                        .foregroundStyle(day.isDone(letter) ? Color.dawn : Color.line)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(day.doneCount) de 6")
            if showStreak {
                Text("Racha: \(Text(streakLabel).bold())")
                    .font(.reading(16, relativeTo: .subheadline))
                    .foregroundStyle(.muted)
            }
        }
    }

    private var streakLabel: String { streak == 1 ? "1 día" : "\(streak) días" }
}
