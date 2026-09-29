import UIKit
import Capacitor
import UserNotifications

// Notifications for the web inside the app. The iPhone schedules them itself: no server and no push, which the
// filter's app list blocked for the web app, and which a free Apple ID can't sign anyway.
// The web calls: permission, ask, schedule {id, at (ms), title, body}, cancel {id}. Scheduling an id again replaces it.
@objc(AvisosPlugin)
public class AvisosPlugin: CAPPlugin, CAPBridgedPlugin, NotificationHandlerProtocol {
    public let identifier = "AvisosPlugin"
    public let jsName = "Avisos"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "permission", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "ask", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "schedule", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "cancel", returnType: CAPPluginReturnPromise)
    ]
    private let center = UNUserNotificationCenter.current()

    override public func load() {
        bridge?.notificationRouter.localNotificationHandler = self
    }

    // The same words the web's Notification.permission uses.
    @objc func permission(_ call: CAPPluginCall) {
        center.getNotificationSettings { settings in
            let s = settings.authorizationStatus
            call.resolve(["permission": s == .authorized || s == .provisional || s == .ephemeral ? "granted" : s == .denied ? "denied" : "default"])
        }
    }

    @objc func ask(_ call: CAPPluginCall) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in self.permission(call) }
    }

    @objc func schedule(_ call: CAPPluginCall) {
        guard let id = call.getString("id"), let at = call.getDouble("at") else {
            call.reject("Falta id o at")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = call.getString("title") ?? ""
        content.body = call.getString("body") ?? ""
        // SAVERS' own soft bell (the E5–B5 pair of softBell in index.html), not the iPhone's generic tone.
        content.sound = UNNotificationSound(named: UNNotificationSoundName("campana.caf"))
        content.threadIdentifier = id
        let secs = max(1, at / 1000 - Date().timeIntervalSince1970)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: secs, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) { error in
            if let error = error { call.reject(error.localizedDescription) } else { call.resolve() }
        }
    }

    @objc func cancel(_ call: CAPPluginCall) {
        if let id = call.getString("id") { center.removePendingNotificationRequests(withIdentifiers: [id]) }
        call.resolve()
    }

    // Shown even while SAVERS is open.
    public func willPresent(notification: UNNotification) -> UNNotificationPresentationOptions {
        return [.banner, .list, .sound]
    }

    // Tapping one brings the web to Hoy, like the web app's notifications did.
    public func didReceive(response: UNNotificationResponse) {
        DispatchQueue.main.async { self.bridge?.triggerWindowJSEvent(eventName: "saversnote") }
    }
}
