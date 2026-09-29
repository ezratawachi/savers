import SwiftUI

/// The box a timer lives in: what's happening, a line under it, the clock, the bar, and its buttons.
struct TimerPanel<Buttons: View>: View {
    let title: String
    let subtitle: String
    /// Visualización's question reads as text, not as a hint.
    var subtitleIsText = false
    /// Seconds on the clock; nil hides the clock and the bar (done, or reading).
    var clock: Int?
    var progress: Double = 0
    @ViewBuilder let buttons: Buttons

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.display(20, relativeTo: .headline, weight: .bold))
                .foregroundStyle(.ink)
            Text(subtitle)
                .font(.reading(subtitleIsText ? 17 : 15, relativeTo: subtitleIsText ? .body : .subheadline))
                .foregroundStyle(subtitleIsText ? Color.ink : Color.muted)
                .lineSpacing(subtitleIsText ? 3 : 0)
                .frame(minHeight: subtitleIsText && clock != nil ? 48 : 0, alignment: .topLeading)
                .padding(.top, 2)
                .fixedSize(horizontal: false, vertical: true)
            if let clock {
                TimerClock(secs: clock)
                    .padding(.top, 8)
                ProgressBar(value: progress)
                    .padding(.top, 6)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { buttons }
                VStack(alignment: .leading, spacing: 8) { buttons }
            }
            .padding(.top, 12)
        }
        .timerBox()
    }

    static func clockText(_ secs: Int) -> String { TimerClock.text(secs) }
}

private struct ProgressBar: View {
    let value: Double

    var body: some View {
        Capsule()
            .fill(Color.surface)
            .frame(height: 6)
            .overlay(alignment: .leading) {
                GeometryReader { g in
                    Capsule()
                        .fill(Color.dawn)
                        .frame(width: g.size.width * min(1, max(0, value)))
                        .animation(.linear(duration: 0.25), value: value)
                }
            }
            .accessibilityHidden(true)
    }
}

/// A timer's button. Prominent: sky, for what you'd tap next; otherwise quiet.
struct TimerButton: ButtonStyle {
    var prominent = false
    /// Just an icon: a 44-pt circle.
    var round = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.reading(16, relativeTo: .body).bold())
            .foregroundStyle(prominent ? Color.white : Color.ink)
            .lineLimit(1)
            .padding(.horizontal, round ? 0 : 16)
            .frame(minWidth: 44, minHeight: 44)
            .background {
                Capsule()
                    .fill(prominent ? Color.sky : Color.surface)
                    .stroke(prominent ? Color.clear : Color.line, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Motion.spring, value: configuration.isPressed)
    }
}

extension View {
    /// A timer's box. Wider than the card's text: it lines up with the circle, so its buttons fit side by side.
    func timerBox() -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.surface2, in: .rect(cornerRadius: 14))
            .padding(.leading, -CardLayout.indent)
    }
}

/// A timer's big clock, "4:32".
struct TimerClock: View {
    let secs: Int

    var body: some View {
        Text(Self.text(secs))
            .font(.display(46, relativeTo: .largeTitle, weight: .heavy))
            .monospacedDigit()
            .foregroundStyle(.ink)
            .contentTransition(.numericText(countsDown: true))
            .animation(.snappy, value: secs)
            .accessibilityLabel(Self.spoken(secs))
    }

    static func text(_ secs: Int) -> String { "\(secs / 60):" + String(format: "%02d", secs % 60) }

    private static func spoken(_ secs: Int) -> String {
        let m = secs / 60, s = secs % 60
        return m > 0 ? "\(m) min \(s) s" : "\(s) segundos"
    }
}
