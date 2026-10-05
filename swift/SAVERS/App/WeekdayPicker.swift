import SwiftUI

/// The seven days in a row, Sunday first, each a circle you turn on or off: on is the sky, off is just its
/// name. For the welcome's "Which days?".
struct WeekdayPicker: View {
    @Binding var days: Set<Int>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { w in
                let on = days.contains(w)
                Button {
                    withAnimation(Motion.pick(Motion.spring, reduce: reduceMotion)) {
                        if on { days.remove(w) } else { days.insert(w) }
                    }
                } label: {
                    Text(Self.name(w))
                        .font(.reading(14, relativeTo: .footnote).bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(on ? Color.night : .muted)
                        .padding(.horizontal, 3)
                        .frame(width: 42, height: 42)
                        .background(on ? Color.sky : Color.surface2, in: .circle)
                        // The whole column is the target, at least 44 pt.
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(PressScale())
                .accessibilityLabel(Weekday.names[w])
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: days)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Which days?")
    }

    /// "Sun", "Lun": three letters, no period.
    private static func name(_ w: Int) -> String {
        let s = Weekday.short[w].replacing(".", with: "")
        return s.prefix(1).uppercased() + s.dropFirst()
    }
}
