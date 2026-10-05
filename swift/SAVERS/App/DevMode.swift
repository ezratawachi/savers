#if DEBUG
import Foundation
import Observation

/// Settings › Developer mode, only in Debug builds (the ones installed from the Mac, never the App Store's):
/// the app as a new install of its own, to live what someone new sees. It stays on, across launches, until you
/// exit; your data, notices, cloud and voice are never touched.
@Observable
final class DevMode {
    private(set) var on = UserDefaults.standard.bool(forKey: DevMode.key)
    /// Changes on every enter, exit or fresh start, so the app builds its world again.
    private(set) var generation = 0
    /// Asked to start from zero: the test app is emptied when its next world is built, after the one running
    /// has stopped and saved, so nothing it had is written back.
    @ObservationIgnored private var wipe = false

    private static let key = "savers:devMode"
    private static let suite = "savers.dev"
    private static let folder = URL.applicationSupportDirectory.appending(path: "savers-dev", directoryHint: .isDirectory)

    func world() -> AppWorld {
        guard on else { return .real() }
        if wipe {
            try? FileManager.default.removeItem(at: Self.folder)
            UserDefaults(suiteName: Self.suite)?.removePersistentDomain(forName: Self.suite)
            wipe = false
        }
        return AppWorld(persistence: Persistence(folder: Self.folder), prefs: LocalPrefs(defaults: UserDefaults(suiteName: Self.suite)!), sandbox: true)
    }

    func enter() { set(true) }

    func exit() { set(false) }

    /// The test app back to a new install: its folder and prefs are emptied once it has stopped (`world()`).
    func startOver() {
        wipe = true
        generation += 1
    }

    private func set(_ value: Bool) {
        on = value
        UserDefaults.standard.set(value, forKey: Self.key)
        generation += 1
    }
}
#endif
