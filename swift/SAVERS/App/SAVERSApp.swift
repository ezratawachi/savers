import SwiftUI

@main
struct SAVERSApp: App {
    @State private var world: AppWorld
    #if DEBUG
    @State private var devMode: DevMode
    #endif

    init() {
        ToneEngine.mixFromLaunch()
        BarAppearance.apply()
        #if DEBUG
        let dev = DevMode()
        _devMode = State(initialValue: dev)
        _world = State(initialValue: Scenario.current.map(AppWorld.init(scenario:)) ?? dev.world())
        #else
        _world = State(initialValue: .real())
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .background(TapToDismissKeyboard())
                .environment(world.store)
                .environment(world.toast)
                .environment(world.cloud)
                .environment(world.runs)
                .environment(world.notices)
                .environment(world.opening)
                // Another world is another app: every screen starts again.
                .id(ObjectIdentifier(world))
                #if DEBUG
                .environment(devMode)
                .overlay(alignment: .top) {
                    // The developer mode's mark: a thin line over the clock, so a real morning isn't logged here.
                    if devMode.on {
                        Color.warn
                            .frame(height: 3)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .onChange(of: devMode.generation) {
                    world.stop()
                    world = devMode.world()
                }
                #endif
        }
    }
}
