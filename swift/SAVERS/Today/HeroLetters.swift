import SwiftUI

/// The six letters as one word: done in terracotta, the rest quiet. Not buttons.
struct HeroLetters: View {
    let day: Day
    let streak: Int
    let showStreak: Bool
    /// "Ver horario ›", when there's a schedule to see.
    var onSchedule: (() -> Void)?

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
            HStack {
                if showStreak {
                    Text("Racha: \(Text(streakLabel).bold())")
                        .font(.reading(16, relativeTo: .subheadline))
                        .foregroundStyle(.muted)
                }
                Spacer(minLength: 8)
                if let onSchedule {
                    Button(action: onSchedule) {
                        Text("Ver horario ›")
                            .font(.reading(16, relativeTo: .subheadline).bold())
                            .foregroundStyle(.sky)
                            .frame(minHeight: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(PressScale())
                }
            }
        }
    }

    private var streakLabel: String { streak == 1 ? "1 día" : "\(streak) días" }
}
