import Foundation
import OSLog
import UserNotifications

actor NotificationService {
    private let center = UNUserNotificationCenter.current()

    func prepare() async {
        let granted = try? await center.requestAuthorization(options: [.alert, .sound])
        Logger.app.info("Notification authorization granted: \(granted == true)")
    }

    func send(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await center.add(request)
    }
}
