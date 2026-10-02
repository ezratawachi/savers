import SwiftUI

/// Read: starts here, opens your reading app, and a notice says when the minutes are over.
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
                Button(rest ? "Repeat" : "Start reading") { runs.startReading() }
                    .buttonStyle(TimerButton(prominent: !rest))
            } else {
                Button("I'm done") { runs.finishReading() }
                    .buttonStyle(TimerButton(prominent: true))
                Button("Cancel") { runs.cancelReading() }
                    .buttonStyle(TimerButton())
            }
        }
    }

    private func title(_ run: ReadingRun?, _ rest: Bool) -> String {
        if run != nil { return String(localized: "Reading") }
        return rest ? String(localized: "All done") : String(localized: "\(runs.readingMinutes()) minutes")
    }

    private func subtitle(_ run: ReadingRun?, _ rest: Bool, _ app: ReadApp) -> String {
        if let run {
            let left = TimerPanel<EmptyView>.clockText(run.left(runs.now))
            return app.url == nil ? String(localized: "\(left) left.") : String(localized: "\(left) left. It checks itself off when you're back.")
        }
        if rest { return String(localized: "If you like, you can read again.") }
        return app.url == nil ? String(localized: "I'll let you know when it's over.") : String(localized: "\(app.name) opens and I'll let you know when it's over.")
    }
}
