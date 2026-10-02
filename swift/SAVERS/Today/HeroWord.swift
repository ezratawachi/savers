import SwiftUI
import UIKit

/// SUNRISE (AMANECER) from margin to margin, on the night. It fills with amber from the bottom up, a sixth for each
/// step done, with a hard edge. Not a button.
struct HeroWord: View {
    let day: Day

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The word's line as drawn (it shrinks to the width), to know how tall its capitals are.
    @State private var lineHeight: CGFloat = 0

    var body: some View {
        let done = day.doneCount
        // Set big and shrunk to the width, so the word always fills it exactly, at any text size.
        word
            .foregroundStyle(Color.nightLetter)
            .accessibilityLabel("Sunrise, \(done) of 6")
            .accessibilityAddTraits(.isHeader)
            .overlay {
                word
                    .foregroundStyle(Color.done)
                    .mask(alignment: .init(horizontal: .center, vertical: .lastTextBaseline)) {
                        fill(done)
                    }
                    // With Reduce Motion the amber fades to its new height instead of rising.
                    .id(reduceMotion ? done : 0)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
            .animation(reduceMotion ? Motion.fade : Motion.sun, value: done)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { lineHeight = $0 }
            .frame(maxWidth: .infinity, alignment: .leading)
            // The line's room above the capitals and for descenders, which they don't use.
            .padding(.top, -8)
            .padding(.bottom, -10)
    }

    private var word: some View {
        // In capitals, so each sixth of the height is a sixth of the word.
        Text("SUNRISE")
            .font(.display(200, relativeTo: .largeTitle, weight: .heavy))
            .tracking(-2)
            .lineLimit(1)
            .minimumScaleFactor(0.05)
    }

    /// From the baseline up to `done` sixths of the capitals; all of it when the six are done, so the round
    /// letters' overshoot is amber too.
    private func fill(_ done: Int) -> some View {
        let cap = lineHeight * Self.capRatio
        let below = cap * 0.04
        let height = done >= Letter.allCases.count ? lineHeight * 2 : CGFloat(done) / 6 * cap + (done > 0 ? below : 0)
        return Rectangle()
            .frame(height: height)
            .offset(y: done > 0 ? below : 0)
    }

    /// The capitals' height as a share of the font's line, the same at any size.
    private static let capRatio: CGFloat = {
        let descriptor = UIFontDescriptor(fontAttributes: [.family: "Bricolage Grotesque"])
        let font = UIFont(descriptor: descriptor, size: 100)
        return font.capHeight / font.lineHeight
    }()
}
