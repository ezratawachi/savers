import SwiftUI

/// Ejercicio en casa: the step, its drawing, the clock, the map of the six parts, and the buttons.
struct ExerciseTimer: View {
    @Environment(Runs.self) private var runs
    let done: Bool

    var body: some View {
        let steps = Exercise.runSteps, run = runs.ex
        let total = Runs.total(steps)
        let el = min(run?.elapsed(runs.now) ?? 0, total - 0.001)
        let idx = run == nil ? 0 : Runs.stepAt(steps, el)
        let step = Exercise.steps[idx]
        // Already marked and not running again: it steps back and offers a repeat.
        let rest = run == nil && done

        VStack(alignment: .leading, spacing: 0) {
            Text(rest ? "Hecho" : run == nil ? "Listo para empezar" : step.rest ? "Cambia de ejercicio" : step.name)
                .font(.display(20, relativeTo: .headline, weight: .bold))
                .foregroundStyle(.ink)
                .contentTransition(.opacity)
            if rest {
                Text("Si quieres, puedes repetirlo.")
                    .font(.reading(15, relativeTo: .subheadline))
                    .foregroundStyle(.muted)
                    .padding(.top, 2)
            } else {
                figure(run: run, idx: idx)
                    .padding(.top, 10)
                    .padding(.bottom, 2)
                TimerClock(secs: run == nil ? Int(total) : max(0, Int((Runs.stepStart(steps, idx) + step.secs - el).rounded(.up))))
                    .padding(.top, 8)
                ExerciseMap(
                    current: run == nil ? -1 : Exercise.part(of: idx),
                    fill: run == nil || step.rest ? 0 : min(1, max(0, (el - Runs.stepStart(steps, idx)) / step.secs))
                )
                .padding(.top, 8)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { buttons(run: run, rest: rest) }
                VStack(alignment: .leading, spacing: 8) { buttons(run: run, rest: rest) }
            }
            .padding(.top, 12)
        }
        .timerBox()
        .sensoryFeedback(.impact(weight: .light), trigger: run?.running)
    }

    /// The first step before starting, the next one (held) during a change.
    @ViewBuilder
    private func figure(run: GuidedRun?, idx: Int) -> some View {
        let step = Exercise.steps[idx]
        let (fig, mode): (Fig, ExerciseFigure.Mode) =
            run == nil || idx == 0 ? (.marcha, .loop)
            : step.rest ? (Exercise.steps[idx + 1].fig ?? .marcha, .ready(Exercise.steps[idx + 1].fig ?? .marcha))
            : (step.fig ?? .marcha, .guided(step: idx))
        ExerciseFigure(fig: fig, mode: mode, elapsed: { runs.ex?.elapsed($0) }, moving: run?.running == true)
            .id(fig)
    }

    @ViewBuilder
    private func buttons(run: GuidedRun?, rest: Bool) -> some View {
        Button(run?.running == true ? "Pausar" : run != nil ? "Seguir" : rest ? "Repetir" : "Empezar") {
            if run?.running == true { runs.pause(.ejercicio) } else { runs.start(.ejercicio) }
        }
        .buttonStyle(TimerButton(prominent: !rest || run != nil))
        if !rest {
            Button("Siguiente") { runs.skip(.ejercicio) }
                .buttonStyle(TimerButton())
        }
        if run != nil {
            Button("Reiniciar", systemImage: "arrow.counterclockwise") { runs.reset(.ejercicio) }
                .labelStyle(.iconOnly)
                .buttonStyle(TimerButton(round: true))
        }
    }
}

/// The six parts in a row, each a short bar that fills: done is terracotta, now has a sky ring.
/// The circuit runs twice, so in round 2 its four parts fill again (the step's name says which round).
private struct ExerciseMap: View {
    /// The part it's in; -1 before starting.
    let current: Int
    /// How far into the current part.
    let fill: Double

    var body: some View {
        WeightedRow(weights: Exercise.map.map(\.weight), spacing: 3) {
            ForEach(Exercise.map.indices, id: \.self) { k in
                let now = k == current
                VStack(spacing: 4) {
                    Capsule()
                        .fill(Color.surface)
                        .frame(height: 6)
                        .overlay(alignment: .leading) {
                            GeometryReader { g in
                                Capsule()
                                    .fill(Color.dawn)
                                    .frame(width: g.size.width * (current < 0 ? 0 : k < current ? 1 : now ? fill : 0))
                                    .animation(.linear(duration: 0.25), value: fill)
                            }
                        }
                        .clipShape(.capsule)
                        .overlay { if now { Capsule().stroke(Color.sky, lineWidth: 1.5) } }
                    Text(Exercise.map[k].name)
                        .font(.reading(11, relativeTo: .caption2).weight(now ? .bold : .regular))
                        .foregroundStyle(now ? Color.sky : Color.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(current < 0 ? "Seis partes" : "Parte \(current + 1) de 6: \(Exercise.map[current].name)")
    }
}

/// Children side by side, each as wide as its share of the weights.
private struct WeightedRow: Layout {
    let weights: [Double]
    let spacing: CGFloat

    private func widths(_ total: CGFloat, _ n: Int) -> [CGFloat] {
        let sum = weights.prefix(n).reduce(0, +), free = max(0, total - spacing * CGFloat(max(0, n - 1)))
        return (0..<n).map { free * CGFloat(weights[$0] / max(sum, 1)) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let w = widths(width, subviews.count)
        let h = subviews.indices.map { subviews[$0].sizeThatFits(ProposedViewSize(width: w[$0], height: nil)).height }.max() ?? 0
        return CGSize(width: width, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (i, w) in widths(bounds.width, subviews.count).enumerated() {
            subviews[i].place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: w, height: bounds.height))
            x += w + spacing
        }
    }
}
