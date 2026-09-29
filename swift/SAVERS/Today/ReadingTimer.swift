import SwiftUI

/// Lectura: starts here, opens your reading app, and a notice says when the minutes are over.
/// Coming back with the time done marks it.
struct ReadingTimer: View {
    @Environment(Runs.self) private var runs
    @Environment(AppStore.self) private var store
    let done: Bool

    var body: some View {
        let run = runs.reading
        let app = ReadApp(store.settings.readApp)
        let rest = run == nil && done

        TimerPanel(title: title(run, rest), subtitle: subtitle(run, rest, app)) {
            if run == nil {
                Button(rest ? "Repetir" : "Empezar lectura") { runs.startReading() }
                    .buttonStyle(TimerButton(prominent: !rest))
            } else {
                Button("Ya terminé") { runs.finishReading() }
                    .buttonStyle(TimerButton(prominent: true))
                Button("Cancelar") { runs.cancelReading() }
                    .buttonStyle(TimerButton())
            }
        }
    }

    private func title(_ run: ReadingRun?, _ rest: Bool) -> String {
        if run != nil { return "Leyendo" }
        return rest ? "Hecho" : "\(runs.readingMinutes()) minutos"
    }

    private func subtitle(_ run: ReadingRun?, _ rest: Bool, _ app: ReadApp) -> String {
        if let run {
            return "Faltan \(TimerPanel<EmptyView>.clockText(run.left(runs.now)))" + (app.url == nil ? "." : ". Se marca sola al volver.")
        }
        if rest { return "Si quieres, puedes leer otra vez." }
        return app.url == nil ? "Te aviso al terminar." : "Se abre \(app.name) y te aviso al terminar."
    }
}
