import SwiftUI

/// The three tabs, the toast, and keeping "today" right across midnight and app switches.
struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(CloudSync.self) private var cloud
    @Environment(Runs.self) private var runs
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab("Hoy", systemImage: "sun.horizon") {
                TodayView()
            }
            Tab("Historial", systemImage: "calendar") {
                HistoryPlaceholder()
            }
            Tab("Ajustes", systemImage: "gearshape") {
                SettingsPlaceholder()
            }
        }
        .tint(.sky)
        .overlay { ToastOverlay() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.refreshToday()
                runs.resume()
                cloud.resume()
            } else if phase == .background {
                store.flush()
                cloud.pause()
            }
        }
        .task { await watchMidnight() }
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
