import UIKit
import UserNotifications

/// AppDelegate handles push notification registration and delivery.
/// Wired into SwiftUI lifecycle via UIApplicationDelegateAdaptor.
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - Push Token Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("[push] APNs token: \(token)")

        // Send to backend.
        Task {
            do {
                let body = DeviceTokenBody(token: token, platform: "ios")
                try await APIClient.shared.requestVoid(
                    Endpoint(path: "/api/devices", method: .POST, body: body)
                )
                print("[push] device token registered with backend")
            } catch {
                print("[push] failed to register token: \(error)")
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[push] registration failed: \(error.localizedDescription)")
    }

    // MARK: - Foreground Notification Handling

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner + badge + sound even when app is in foreground.
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap — deep link handling can be added here.
        let userInfo = response.notification.request.content.userInfo
        print("[push] notification tapped: \(userInfo)")
        completionHandler()
    }
}

// MARK: - Request Body

private struct DeviceTokenBody: Encodable {
    let token: String
    let platform: String
}
