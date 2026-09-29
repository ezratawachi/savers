import SwiftUI

/// Where you should be in the letter you're on. It walks the line in the letter's minutes from the hour it
/// should start; the last minute is amber; once time is up it waits at the end and says what comes next.
/// It never blinks, sounds or turns red.
struct SunLine: View {
    let start: Int
    let length: Int
    let next: String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let s = state(at: context.date)
            HStack(spacing: 10) {
                Canvas { g, size in draw(g, size, s) }
                    .frame(height: 12)
                    .accessibilityHidden(true)
                Text(s.label)
                    .font(.reading(13, relativeTo: .caption).bold())
                    .monospacedDigit()
                    .foregroundStyle(s.last || s.over ? Color.sunInk : Color.muted)
                    .lineLimit(1)
                    .fixedSize()
            }
            .accessibilityElement(children: .combine)
        }
    }

    private struct SunState {
        var p: Double
        var zone: Double
        var over: Bool
        var last: Bool
        var label: String
    }

    private func state(at date: Date) -> SunState {
        let c = DayKey.calendar.dateComponents([.hour, .minute, .second], from: date)
        let now = Double((c.hour ?? 0) * 60 + (c.minute ?? 0)) + Double(c.second ?? 0) / 60
        let len = Double(length)
        let left = Double(start) + len - now
        let p = min(1, max(0, (now - Double(start)) / len))
        let over = left <= 0
        let label = over ? (next.isEmpty ? "0 min" : "Sigue \(next)") : "\(Int(min(left, len).rounded(.up))) min"
        return SunState(p: p, zone: max(0, (len - 1) / len), over: over, last: !over && left <= 1, label: label)
    }

    private func draw(_ g: GraphicsContext, _ size: CGSize, _ s: SunState) {
        let r = 5.0
        let y = size.height / 2
        let x0 = r, x1 = size.width - r
        let w = x1 - x0
        func bar(_ from: Double, _ to: Double, _ height: Double, _ color: Color) {
            guard to > from else { return }
            let rect = CGRect(x: x0 + from * w, y: y - height / 2, width: (to - from) * w, height: height)
            g.fill(Path(roundedRect: rect, cornerRadius: height / 2), with: .color(color))
        }
        bar(0, 1, 2, .line)
        bar(s.zone, 1, 4, .sunZone)
        bar(0, s.p, 4, .sunTrail)
        let x = x0 + s.p * w
        g.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.sun))
    }
}
