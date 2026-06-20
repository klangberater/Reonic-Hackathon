import Foundation
import UserNotifications

enum NotificationManager {
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
