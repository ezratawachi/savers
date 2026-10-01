import SwiftUI

/// "JUEVES 1 OCT · GYM" over the day's one big title, and a quiet line under it.
struct TodayHeader: View {
    enum Title {
        case letters(Day)
        case shabbat
        case free

        var isLetters: Bool {
            if case .letters = self { true } else { false }
        }
    }

    let ds: String
    let type: DayType
    let title: Title
    /// "6 días seguidos", "Hoy no toca SAVERS"; nil hides the line.
    let note: String?
    /// A save that failed takes the line, in the warning color.
    let status: String?
    let onDay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            dayLine
            titleView
            if let line = status ?? note {
                Text(line)
                    .font(.reading(16, relativeTo: .subheadline))
                    .foregroundStyle(status == nil ? Color.muted : Color.warn)
            }
        }
    }

    // MARK: The day

    /// The whole line opens the day's sheet, except on Shabbat.
    @ViewBuilder
    private var dayLine: some View {
        if type == .shabbat {
            dayText
        } else {
            Button(action: onDay) {
                HStack(spacing: 5) {
                    dayText
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.muted)
                }
                // A 44-pt target without making the line look bigger.
                .padding(.vertical, 13)
                .contentShape(.rect)
                .padding(.vertical, -13)
            }
            .buttonStyle(PressScale())
            .accessibilityLabel("\(DayKey.head(ds)), \(type.chipName). Cambiar este día")
        }
    }

    /// Only what's out of the ordinary is named: a normal day is just its date.
    private var dayText: some View {
        let date = Text(DayKey.head(ds))
        let line = type == .gym ? Text("\(date) · \(Text("Gym").bold().foregroundStyle(.ink))") : date
        return line
            .font(.reading(13, relativeTo: .footnote))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(.muted)
    }

    // MARK: The title

    @ViewBuilder
    private var titleView: some View {
        switch title {
        case .letters(let day):
            HeroLetters(day: day)
        case .shabbat:
            restTitle("Shabbat Shalom")
        case .free:
            restTitle("Día libre")
        }
    }

    private func restTitle(_ text: String) -> some View {
        Text(text)
            .font(.display(52, relativeTo: .largeTitle, weight: .heavy))
            .tracking(-1)
            .foregroundStyle(.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityAddTraits(.isHeader)
    }
}
