import SwiftUI
import UserNotifications

@main
struct EventAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authStore = AuthStore()
    @StateObject private var appEnv = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authStore)
                .environmentObject(appEnv)
                .task {
                    await requestNotificationPermission()
                }
        }
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                print("[push] notification permission granted")
            } else {
                print("[push] notification permission denied")
            }
        } catch {
            print("[push] permission request failed: \(error)")
        }
    }
}
