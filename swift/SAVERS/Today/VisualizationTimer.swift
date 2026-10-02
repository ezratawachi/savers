import SwiftUI

/// Imagine's guided timer: a minute per question, read aloud.
struct VisualizationTimer: View {
    @Environment(Runs.self) private var runs
    let done: Bool

    var body: some View {
        let steps = runs.visSteps
        if !steps.isEmpty { panel(steps) }
    }

    private func panel(_ steps: [RunStep]) -> some View {
        let run = runs.vis
        let total = Runs.total(steps)
        let el = min(run?.elapsed(runs.now) ?? 0, max(0, total - 0.001))
        let idx = run == nil ? 0 : Runs.stepAt(steps, el)
        // Already marked and not running again: it steps back and offers a repeat.
        let rest = run == nil && done
        let clock = run == nil ? Int(total) : Int((Runs.stepStart(steps, idx) + steps[idx].secs - el).rounded(.up))

        return TimerPanel(
            title: rest ? String(localized: "All done") : run == nil ? String(localized: "Close your eyes and listen") : String(localized: "Question \(idx + 1) of \(steps.count)"),
            subtitle: rest ? String(localized: "If you like, you can do it again.") : run == nil ? String(localized: "The voice reads you each question and gives you a minute.") : steps[idx].text,
            subtitleIsText: run != nil,
            clock: rest ? nil : max(0, clock),
            progress: run == nil || total == 0 ? 0 : el / total
        ) {
            Button(run?.running == true ? "Pause" : run != nil ? "Resume" : rest ? "Repeat" : "Start") {
                if run?.running == true { runs.pause(.visualizacion) } else { runs.start(.visualizacion) }
            }
            .buttonStyle(TimerButton(prominent: !rest || run != nil))
            if !rest {
                Button("Next") { runs.skip(.visualizacion) }
                    .buttonStyle(TimerButton())
            }
            if run != nil {
                Button("Restart", systemImage: "arrow.counterclockwise") { runs.reset(.visualizacion) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(TimerButton(round: true))
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: run?.running)
    }
}
