import Foundation

/// What the app runs on: the store and everything that hangs from it. The developer mode swaps it for a new
/// install of its own, with its own folder and prefs, no cloud, no notices and the iPhone's voice.
final class AppWorld {
    let store: AppStore
    let toast = Toast()
    let cloud: CloudSync
    let runs: Runs
    let notices: Notices
    let opening: Opening

    /// Your real app.
    static func real() -> AppWorld { AppWorld(persistence: .standard, prefs: .standard, sandbox: false) }

    init(persistence: Persistence, prefs: LocalPrefs, sandbox: Bool) {
        store = AppStore(persistence: persistence, prefs: prefs)
        // A new install, with nothing on it and no account: the welcome first.
        opening = Opening(welcoming: !store.settings.hasPersonalData && store.days.isEmpty && prefs["cloudUid"] == nil)
        cloud = CloudSync(store: store, prefs: prefs, blocked: sandbox)
        notices = Notices(store: store, prefs: prefs, quiet: sandbox)
        runs = Runs(store: store, toast: toast, notices: notices, prefs: prefs)
        GeminiVoice.shared.sandboxed = sandbox
        GeminiVoice.shared.phrases = { [store] in Self.spokenPhrases(store.settings) }
    }

    #if DEBUG
    /// A scenario of `/probar`: made-up data, already in its own folder and prefs.
    init(scenario: Scenario) {
        store = scenario.makeStore()
        opening = Opening(welcoming: !store.settings.hasPersonalData && store.days.isEmpty)
        cloud = CloudSync(store: store, prefs: Scenario.prefs)
        notices = Notices(store: store, prefs: Scenario.prefs)
        runs = Runs(store: store, toast: toast, notices: notices, prefs: Scenario.prefs)
        GeminiVoice.shared.phrases = { [store] in Self.spokenPhrases(store.settings) }
    }
    #endif

    /// Before another world takes its place: what's written is saved and nothing keeps running.
    func stop() {
        store.flush()
        cloud.pause()
        runs.halt()
    }

    /// Everything the app can say today, with the tone it's said in: what Gemini prepares.
    private static func spokenPhrases(_ settings: AppSettings) -> [(String, SpeechTone)] {
        var out: [(String, SpeechTone)] = [(Exercise.doneCue, .notice), (Runs.visualizationDoneCue, .notice)]
        out += Workout.of(settings).phrases.map { ($0, .energetic) }
        out += GuideEvent.words
        out += settings.visualization.items.filled.map { ($0.text.trimmingCharacters(in: .whitespacesAndNewlines), .calm) }
        return out
    }
}
