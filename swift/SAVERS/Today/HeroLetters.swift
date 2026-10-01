import SwiftUI

/// SAVERS from margin to margin: done in terracotta, the rest quiet. Not buttons.
struct HeroLetters: View {
    let day: Day

    var body: some View {
        // Set big and shrunk to the width, so the word always fills it exactly, at any text size.
        word
            .font(.display(200, relativeTo: .largeTitle, weight: .heavy))
            .tracking(-2)
            .lineLimit(1)
            .minimumScaleFactor(0.05)
            .frame(maxWidth: .infinity, alignment: .leading)
            // The line's room above the capitals and for descenders, which they don't use.
            .padding(.top, -8)
            .padding(.bottom, -10)
            .accessibilityLabel("SAVERS, \(day.doneCount) de 6")
            .accessibilityAddTraits(.isHeader)
    }

    private var word: Text {
        Letter.allCases.reduce(Text(verbatim: "")) { word, letter in
            Text("\(word)\(Text(letter.initial).foregroundStyle(day.isDone(letter) ? Color.dawn : Color.line))")
        }
    }
}
