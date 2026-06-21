import Foundation
import UserNotifications

/// Where a tapped notification should take the user. PlanDayView observes `pending` and acts on it.
final class AppRouter: ObservableObject {
    static let shared = AppRouter()
    @Published var pending: String?   // "plan" | "anomaly"
}

enum NotificationManager {
    struct Reminder { let id: String; let title: String; let body: String; let fireAt: Date }

    /// Request permission and schedule one reminder per planned task. Replaces any prior plan
    /// reminders. Tasks whose fire time has already passed (a pinned/elapsed demo clock) are
    /// staggered a few seconds out so they still arrive — the reminder still works on stage.
    /// Calls back on the main thread with whether permission was granted.
    static func schedulePlan(_ reminders: [Reminder], completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
            guard granted else { return }
            let prior = reminders.map { "lumen-plan-\($0.id)" }
            center.removePendingNotificationRequests(withIdentifiers: prior)
            let now = Date()
            var demoDelay: TimeInterval = 8
            for r in reminders {
                let content = UNMutableNotificationContent()
                content.title = r.title
                content.body = r.body
                content.sound = .default

                let trigger: UNNotificationTrigger
                if r.fireAt > now.addingTimeInterval(5) {
                    let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: r.fireAt)
                    trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                } else {
                    trigger = UNTimeIntervalNotificationTrigger(timeInterval: demoDelay, repeats: false)
                    demoDelay += 6
                }
                center.add(UNNotificationRequest(identifier: "lumen-plan-\(r.id)", content: content, trigger: trigger))
            }
        }
    }

    /// Schedule a local reminder to run a device at the chosen hour (today, real time).
    /// If that time has already passed today, fire shortly after so the demo still shows it.
    static func scheduleReminder(deviceName: String, atHour hour: Int) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Time to run your \(deviceName.lowercased())"
            content.body = "You're in a green window — your solar is covering it."
            content.sound = .default

            let cal = Calendar.current
            var comps = cal.dateComponents([.year, .month, .day], from: Date())
            comps.hour = hour; comps.minute = 0
            let target = cal.date(from: comps) ?? Date().addingTimeInterval(8)
            let fire = target > Date() ? target : Date().addingTimeInterval(8)
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fire),
                repeats: false)
            center.add(UNNotificationRequest(identifier: "lumen-\(deviceName)-\(hour)", content: content, trigger: trigger))
        }
    }

    // MARK: - Morning briefing

    private static let briefingId = "lumen-morning-briefing"

    /// Show banners even while the app is foregrounded — otherwise the "Preview" button looks
    /// like it does nothing in the demo (iOS suppresses foreground banners by default).
    private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
        func userNotificationCenter(_ center: UNUserNotificationCenter,
                                    willPresent notification: UNNotification,
                                    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
            completionHandler([.banner, .sound])
        }
        // Tapping the briefing deep-links into the app (build the plan, or open the assistant).
        func userNotificationCenter(_ center: UNUserNotificationCenter,
                                    didReceive response: UNNotificationResponse,
                                    withCompletionHandler completionHandler: @escaping () -> Void) {
            let route = response.notification.request.content.userInfo["route"] as? String
            DispatchQueue.main.async { AppRouter.shared.pending = route }
            completionHandler()
        }
    }
    private static let presenter = ForegroundPresenter()

    /// Call once at launch so foreground notifications present as banners.
    static func configure() { UNUserNotificationCenter.current().delegate = presenter }

    /// Daily morning briefing — a repeating local notification at the user's chosen time.
    static func scheduleMorningBriefing(hour: Int, minute: Int, title: String, body: String, route: String) {
        let center = UNUserNotificationCenter.current()
        center.delegate = presenter
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            center.removePendingNotificationRequests(withIdentifiers: [briefingId])
            let content = UNMutableNotificationContent()
            content.title = title; content.body = body; content.sound = .default
            content.userInfo = ["route": route]
            var comps = DateComponents(); comps.hour = hour; comps.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            center.add(UNNotificationRequest(identifier: briefingId, content: content, trigger: trigger))
        }
    }

    static func cancelMorningBriefing() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [briefingId])
    }

    /// Fire the briefing right now — lets the demo show it without waiting until 7am.
    static func previewBriefing(title: String, body: String, route: String) {
        let center = UNUserNotificationCenter.current()
        center.delegate = presenter
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title; content.body = body; content.sound = .default
            content.userInfo = ["route": route]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.5, repeats: false)
            center.add(UNNotificationRequest(identifier: "lumen-briefing-preview", content: content, trigger: trigger))
        }
    }
}
