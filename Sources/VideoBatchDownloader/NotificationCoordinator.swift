import AppKit
import Foundation
import UserNotifications

final class NotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCoordinator()
    var onSessionRepairRequested: ((UUID) -> Void)?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func activate() {
        UNUserNotificationCenter.current().delegate = self
    }

    func notifyDownloadCompleted(title: String, filePath: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Download complete"
            content.body = title
            content.sound = .default
            content.userInfo = ["filePath": filePath]
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request)
        }
    }

    func notifyBrowserSessionIssue(title: String, body: String, jobID: UUID) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.userInfo = [
                "action": "repairBrowserSession",
                "jobID": jobID.uuidString,
            ]
            let request = UNNotificationRequest(
                identifier: "browser-session-\(jobID.uuidString)",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if userInfo["action"] as? String == "repairBrowserSession",
           let rawJobID = userInfo["jobID"] as? String,
           let jobID = UUID(uuidString: rawJobID) {
            DispatchQueue.main.async { [weak self] in
                self?.onSessionRepairRequested?(jobID)
            }
        } else if let filePath = userInfo["filePath"] as? String {
            DispatchQueue.main.async {
                NSWorkspace.shared.open(URL(fileURLWithPath: filePath))
            }
        }
        completionHandler()
    }
}
