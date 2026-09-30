import SwiftUI

/// The three tabs, the toast, and keeping "today" right across midnight and app switches.
struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(CloudSync.self) private var cloud
    @Environment(Runs.self) private var runs
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = AppTab.today
    @State private var historyOpened = 0

    var body: some View {
        TabView(selection: $tab) {
            Tab("Hoy", systemImage: "sun.horizon", value: .today) {
                TodayView()
            }
            Tab("Historial", systemImage: "calendar", value: .history) {
                HistoryView(opened: historyOpened)
            }
            Tab("Ajustes", systemImage: "gearshape", value: .settings) {
                SettingsView()
            }
        }
        .onChange(of: tab) { _, new in
            if new == .history { historyOpened += 1 }
        }
        .tint(.sky)
        .overlay { ToastOverlay() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.refreshToday()
                runs.resume()
                cloud.resume()
                GeminiVoice.shared.prepare()
            } else if phase == .background {
                store.flush()
                cloud.pause()
            }
        }
        .onChange(of: store.settings.visualization) { GeminiVoice.shared.prepare() }
        .task {
            GeminiVoice.shared.prepare()
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
