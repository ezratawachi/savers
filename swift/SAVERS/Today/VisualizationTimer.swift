import SwiftUI

/// Visualización's guided timer: a minute per question, read aloud.
struct VisualizationTimer: View {
    @Environment(Runs.self) private var runs
    let done: Bool

    var body: some View {
        let steps = runs.visSteps
        if !steps.isEmpty { panel(steps) }
    }

    private func panel(_ steps: [RunStep]) -> some View {
        let run = runs.vis
        let total = runs.total(steps)
        let el = min(run?.elapsed(runs.now) ?? 0, max(0, total - 0.001))
        let idx = run == nil ? 0 : runs.stepAt(steps, el)
        // Already marked and not running again: it steps back and offers a repeat.
        let rest = run == nil && done
        let clock = run == nil ? Int(total) : Int((runs.stepStart(steps, idx) + steps[idx].secs - el).rounded(.up))

        return TimerPanel(
            title: rest ? "Hecho" : run == nil ? "Cierra los ojos y escucha" : "Pregunta \(idx + 1) de \(steps.count)",
            subtitle: rest ? "Si quieres, puedes repetirlo." : run == nil ? "La voz te lee cada pregunta y te da un minuto." : steps[idx].text,
            subtitleIsText: run != nil,
            clock: rest ? nil : max(0, clock),
            progress: run == nil || total == 0 ? 0 : el / total
        ) {
            Button(run?.running == true ? "Pausar" : run != nil ? "Seguir" : rest ? "Repetir" : "Empezar") {
                if run?.running == true { runs.pauseVis() } else { runs.startVis() }
            }
            .buttonStyle(TimerButton(prominent: !rest || run != nil))
            if !rest {
                Button("Siguiente") { runs.skipVis() }
                    .buttonStyle(TimerButton())
            }
            if run != nil {
                Button("Reiniciar", systemImage: "arrow.counterclockwise") { runs.resetVis() }
                    .labelStyle(.iconOnly)
                    .buttonStyle(TimerButton(round: true))
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: run?.running)
    }
}
