import SwiftUI

/// The three tabs, the toast, the opening, and keeping "today" right across midnight and app switches.
struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(CloudSync.self) private var cloud
    @Environment(Runs.self) private var runs
    @Environment(Notices.self) private var notices
    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
    @State private var tab = Scenario.current?.tab ?? .today
    #else
    @State private var tab = AppTab.today
    #endif
    @State private var historyOpened = 0
    @Environment(Opening.self) private var opening

    var body: some View {
        TabView(selection: $tab) {
            Tab("Today", systemImage: "sun.horizon", value: .today) {
                TodayView()
            }
            Tab("History", systemImage: "calendar", value: .history) {
                HistoryView(opened: historyOpened)
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView()
            }
        }
        // Under the welcome, Today isn't there yet for VoiceOver.
        .accessibilityHidden(opening.welcoming)
        .onChange(of: tab) { _, new in
            if new == .history { historyOpened += 1 }
        }
        .tint(.sky)
        .overlay { ToastOverlay() }
        .overlay {
            if !opening.done { OpeningCurtain() }
        }
        .overlay {
            if opening.welcoming { WelcomeView().accessibilityAddTraits(.isModal).transition(.opacity) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.refreshToday()
                runs.resume()
                cloud.resume()
                GeminiVoice.shared.prepare()
                notices.planSoon()
            } else if phase == .background {
                store.flush()
                cloud.pause()
            }
        }
        .onChange(of: store.settings.visualization) { GeminiVoice.shared.prepare() }
        // A changed hour, a marked Lectura, a reviewed month or a new day moves the notices.
        .onChange(of: store.settings) { notices.planSoon() }
        .onChange(of: store.days) { notices.planSoon() }
        .onChange(of: store.affReviewed) { notices.planSoon() }
        .onChange(of: store.today) { notices.planSoon() }
        // A tapped notice opens Hoy, which opens what it's about.
        .onChange(of: notices.tapped, initial: true) { _, id in
            if id != nil { tab = .today }
        }
        .task {
            GeminiVoice.shared.prepare()
            notices.planSoon()
            await watchMidnight()
        }
    }

    private func watchMidnight() async {
        while !Task.isCancelled {
            let cal = DayKey.calendar
            let next = cal.nextDate(after: .now, matching: DateComponents(hour: 0, minute: 0, second: 1), matchingPolicy: .nextTime) ?? .now.addingTimeInterval(3600)
            try? await Task.sleep(for: .seconds(max(1, next.timeIntervalSinceNow)))
            store.refreshToday()
            runs.resume()
        }
    }
}

enum AppTab: Hashable {
    case today, history, settings
}
