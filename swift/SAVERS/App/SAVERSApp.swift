import SwiftUI

@main
struct SAVERSApp: App {
    @State private var store: AppStore
    @State private var toast: Toast
    @State private var cloud: CloudSync
    @State private var runs: Runs
    @State private var notices: Notices

    init() {
        ToneEngine.mixFromLaunch()
        BarAppearance.apply()
        let store = AppStore()
        let toast = Toast()
        _store = State(initialValue: store)
        _toast = State(initialValue: toast)
        _cloud = State(initialValue: CloudSync(store: store))
        let notices = Notices(store: store)
        _notices = State(initialValue: notices)
        _runs = State(initialValue: Runs(store: store, toast: toast, notices: notices))
        GeminiVoice.shared.phrases = { [store] in Self.spokenPhrases(store.settings) }
    }

    /// Everything the app can say today, with the tone it's said in: what Gemini prepares.
    private static func spokenPhrases(_ settings: AppSettings) -> [(String, SpeechTone)] {
        var out: [(String, SpeechTone)] = [(Exercise.marchCue, .energetic), (Exercise.doneCue, .notice), ("Visualización lista.", .notice)]
        for (i, s) in Exercise.steps.enumerated() where i > 0 && !s.rest { out.append((Exercise.cue(i), .energetic)) }
        for (i, s) in Exercise.steps.enumerated() where !s.rest { out.append((Exercise.cueFull(i), .energetic)) }
        out += GuideEvent.words
        out += settings.visualization.items.filled.map { ($0.text.trimmingCharacters(in: .whitespacesAndNewlines), .calm) }
        return out
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(toast)
                .environment(cloud)
                .environment(runs)
                .environment(notices)
        }
    }
}
