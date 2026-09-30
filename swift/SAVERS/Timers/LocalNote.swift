import UserNotifications

/// A notification from this same iPhone, with SAVERS' bell. Scheduling an id again replaces it.
enum LocalNote {
    /// Asks the first time; afterwards answers what you chose.
    static func allowed() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .notDetermined: return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default: return false
        }
    }

    /// At that hour on the clock: a notice for 9:30 pm stays at 9:30 pm.
    static func schedule(id: String, at date: Date, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound(named: UNNotificationSoundName("campana.caf"))
        content.threadIdentifier = id
        let when = DayKey.calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: max(date, .now.addingTimeInterval(1)))
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel(_ id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
