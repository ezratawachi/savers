import SwiftUI

/// The top of Hoy is the icon's night: "JUEVES 1 OCT · GYM", the day's one big title, a quiet line, and
/// Sunling on the horizon that closes it. On a day without the routine the night takes most of the screen
/// and he sleeps in the middle of it.
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
    /// How far up Sunling is, and whether his halo is lit, on a day with the letters.
    let pose: SunlingPose
    let lit: Bool
    let onDay: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(Opening.self) private var opening

    var body: some View {
        NightBand {
            Group {
                if title.isLetters {
                    VStack(alignment: .leading, spacing: 0) {
                        dayLine
                        titleView
                        // The line under the title; Sunling below it, on the horizon at the right.
                        ZStack(alignment: .topLeading) {
                            Color.clear.frame(height: 72)
                            line
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .bottomTrailing) {
                            landing(Sunling(pose: pose, lit: lit).frame(width: 104), pose: pose, lit: lit)
                                // His body, not his halo, lines up with the margin.
                                .padding(.trailing, -10)
                                .animation(Motion.pick(Motion.sun, reduce: reduceMotion), value: pose)
                                .animation(Motion.pick(Motion.sun, reduce: reduceMotion), value: lit)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        dayLine
                        titleView
                        line
                        Spacer(minLength: 32)
                        landing(Sunling(pose: .asleep).frame(maxWidth: 290), pose: .asleep, lit: false)
                            .frame(maxWidth: .infinity)
                    }
                    .containerRelativeFrame(.vertical, alignment: .top) { height, _ in height * 0.7 }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { y in
            if !opening.done { opening.horizon = y }
        }
    }

    /// Tells the opening where Sunling is and how he looks, so it lands on him.
    private func landing(_ bird: some View, pose: SunlingPose, lit: Bool) -> some View {
        bird
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                if !opening.done { opening.bird = frame }
            }
            .onChange(of: pose, initial: true) {
                if !opening.done { opening.pose = pose }
            }
            .onChange(of: lit, initial: true) {
                if !opening.done { opening.lit = lit }
            }
    }

    @ViewBuilder
    private var line: some View {
        if let line = status ?? note {
            Text(line)
                .font(.reading(16, relativeTo: .subheadline))
                .foregroundStyle(status == nil ? Color.muted : Color.warn)
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
