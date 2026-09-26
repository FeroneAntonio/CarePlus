import Foundation
import UIKit
import UserNotifications

// MARK: - Reminder offsets
enum ReminderOffset: Int, CaseIterable, Identifiable {
    case one = 1
    case three = 3
    case five = 5
    case ten = 10
    case fifteen = 15
    case twenty = 20
    case thirty = 30
    case fortyFive = 45
    case sixty = 60

    var id: Int { rawValue }

    var title: String {
        if rawValue < 60 { return "\(rawValue) min" }
        return "1 hour"
    }
}

final class NotificationManager: NSObject {

    private static let calmingPhrases: [String] = [
        "Make a deep breath, you are okay.",
        "Stay chill grandpa u are fine",
        "Take a moment for your self and take a nap if you need one.",
        "Remember your family loves you a lot. You are not alone.",
        "Take a cup of water you are safe"
    ]

    private static let categoryId = "CALL_REMINDER_CATEGORY"
    private static let actionCallId = "CALL_ACTION"
    private static let phoneKey = "phone"

    static func requestAuthorization() {
        let center = UNUserNotificationCenter.current()

        // Delegate on main thread
        DispatchQueue.main.async {
            center.delegate = shared
        }

        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }

        let callAction = UNNotificationAction(
            identifier: actionCallId,
            title: "Call",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryId,
            actions: [callAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    /// Schedules a call reminder *offset minutes before* the given date.
    /// - Note: default offset is 5 minutes to preserve legacy behavior.
    static func scheduleCallReminder(
        id: String,
        title: String,
        phone: String?,
        date: Date,
        offset: ReminderOffset = .five
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Promemory"

        if let phone, !phone.isEmpty {
            content.body = "Call \(phone): \(title)"
            content.userInfo[phoneKey] = phone
            content.categoryIdentifier = categoryId
        } else {
            content.body = title
        }

        content.sound = .default

        // Compute "date - offset"
        let triggerDate = Calendar.current.date(byAdding: .minute, value: -offset.rawValue, to: date) ?? date

        // Avoid scheduling in the past (happens easily with 1-minute reminders)
        guard triggerDate > Date() else {
            // Optional: schedule "now" instead of dropping it:
            // let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            // let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            // UNUserNotificationCenter.current().add(request)
            return
        }

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancel(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    static func scheduleMedicineExpiryReminder(for item: MedicineInventoryItem) {
        let center = UNUserNotificationCenter.current()
        let identifier = medicineExpiryNotificationId(for: item.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let expiryDay = calendar.startOfDay(for: item.expiryDate)
        guard expiryDay >= today else { return }

        let preferredDay = calendar.date(byAdding: .day, value: -30, to: expiryDay) ?? expiryDay
        let reminderDay = max(preferredDay, today)
        var components = calendar.dateComponents([.year, .month, .day], from: reminderDay)
        components.hour = 9
        components.minute = 0

        guard var reminderDate = calendar.date(from: components) else { return }
        if reminderDate <= .now {
            reminderDate = Date().addingTimeInterval(5)
        }

        let content = UNMutableNotificationContent()
        content.title = "Medicine expiry reminder"
        content.body = "\(item.name) expires on \(item.expiryDate.formatted(date: .abbreviated, time: .omitted))."
        content.sound = .default

        let triggerComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    static func cancelMedicineExpiryReminder(for itemID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [medicineExpiryNotificationId(for: itemID)]
        )
    }

    private static func medicineExpiryNotificationId(for itemID: UUID) -> String {
        "medicine_expiry_\(itemID.uuidString)"
    }

    static func scheduleRepeatCallWarning(for contactName: String, phone: String?) {
        let content = UNMutableNotificationContent()
        content.title = "Attention"
        content.body = "You have already called \(contactName) today."
        if let phone, !phone.isEmpty {
            content.userInfo[phoneKey] = phone
            content.categoryIdentifier = categoryId
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let id = "repeat_call_warning_\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func scheduleCalmingReminders(intervalMinutes: Int, startNow: Bool = true, count: Int = 12) {
        let interval = max(1, min(120, intervalMinutes))
        let center = UNUserNotificationCenter.current()

        for i in 0..<max(1, count) {
            let content = UNMutableNotificationContent()
            content.title = "Relax"
            content.body = calmingPhrases.randomElement() ?? "Make a deep breath."
            content.sound = .default

            let minutesFromNow = startNow ? (1 + i * interval) : ((i + 1) * interval)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutesFromNow * 60), repeats: false)
            let id = "calming_\(UUID().uuidString)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(request)
        }
    }

    static func cancelCalmingReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix("calming_") }.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Delegate

    private static let shared = NotificationDelegate()

    private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

        func userNotificationCenter(_ center: UNUserNotificationCenter,
                                    willPresent notification: UNNotification,
                                    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
            completionHandler([.banner, .sound, .badge])
        }

        func userNotificationCenter(_ center: UNUserNotificationCenter,
                                    didReceive response: UNNotificationResponse,
                                    withCompletionHandler completionHandler: @escaping () -> Void) {

            if response.actionIdentifier == actionCallId {
                if let phone = response.notification.request.content.userInfo[phoneKey] as? String {
                    let digits = phone.filter(\.isNumber)
                    if let url = URL(string: "tel://\(digits)") {
                        DispatchQueue.main.async {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
            completionHandler()
        }
    }
}
