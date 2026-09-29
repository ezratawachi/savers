import SwiftUI

@main
struct SAVERSApp: App {
    @State private var store: AppStore
    @State private var toast: Toast
    @State private var cloud: CloudSync
    @State private var runs: Runs

    init() {
        let store = AppStore()
        let toast = Toast()
        _store = State(initialValue: store)
        _toast = State(initialValue: toast)
        _cloud = State(initialValue: CloudSync(store: store))
        _runs = State(initialValue: Runs(store: store, toast: toast))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(toast)
                .environment(cloud)
                .environment(runs)
        }
    }
}
