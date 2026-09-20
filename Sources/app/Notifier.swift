import Foundation
import UserNotifications

final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    var onStatusChange: (() -> Void)?
    private(set) var denied = false

    func prepare() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.getNotificationSettings { [weak self] settings in
            if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .sound]) { _, error in
                    if let error { Log.error("notify: \(error.localizedDescription)") }
                    self?.refresh()
                }
            } else {
                self?.refresh()
            }
        }
    }

    func refresh() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let status = settings.authorizationStatus
            DispatchQueue.main.async {
                guard let self else { return }
                Log.info("notify: system permission \(Notifier.label(status))")
                let denied = status == .denied
                guard self.denied != denied else { return }
                self.denied = denied
                self.onStatusChange?()
            }
        }
    }

    private static func label(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .notDetermined: return "not determined"
        case .provisional: return "provisional"
        default: return "unknown"
        }
    }

    func post(_ notice: Notice) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        switch notice {
        case .timerExpired:
            content.title = L("GiGi stopped")
            content.body = L("The timer ran out, so GiGi stopped keeping the display awake.")
        case .batteryStop(let percent, let limit):
            content.title = L("GiGi stopped")
            content.body = String(format: L("The battery is at %d%% and the limit is %d%%."), percent, limit)
        case .missingAccessibility:
            content.title = L("GiGi needs Accessibility permission")
            content.body = L("Grant it in System Settings > Privacy & Security > Accessibility.")
        case .updateAvailable(let version):
            content.title = String(format: L("GiGi %@ is available"), version)
            content.body = L("Open Settings in the panel to see the release page.")
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Log.error("notify: cannot post (\(error.localizedDescription))")
            } else {
                Log.info("notify: posted \(content.title) — \(content.body)")
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
