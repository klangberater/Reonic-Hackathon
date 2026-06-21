import Foundation
import UserNotifications

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
}
