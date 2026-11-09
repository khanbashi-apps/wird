import SwiftUI
import UIKit
import UserNotifications
import BackgroundTasks
import AppIntents

@main
struct WirdApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            WebContainer()
                .ignoresSafeArea()
        }
    }
}

struct WebContainer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> WebViewController { WebViewController.shared }
    func updateUIViewController(_ vc: WebViewController, context: Context) {}
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static let refreshTaskID = "om.alkhanbashi.wird.refresh"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskID, using: nil) { task in
            Self.handleRefresh(task)
        }
        WirdShortcuts.updateAppShortcutParameters()
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        Self.scheduleRefresh()
    }

    static func scheduleRefresh() {
        let req = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        req.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        try? BGTaskScheduler.shared.submit(req)
    }

    private static func handleRefresh(_ task: BGTask) {
        scheduleRefresh()
        Reminders.reschedule { task.setTaskCompleted(success: true) }
        task.expirationHandler = { task.setTaskCompleted(success: false) }
    }

    // Show reminders while the app is open too.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    // Tapping a reminder opens the matching screen.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let route = response.notification.request.content.userInfo["route"] as? String {
            DispatchQueue.main.async { WebViewController.shared.open(route: route) }
        }
        completionHandler()
    }
}

struct WirdShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddIstighfarIntent(),
            phrases: [
                "استغفر في \(.applicationName)",
                "\(.applicationName) استغفر",
                "Istighfar in \(.applicationName)"
            ],
            shortTitle: "استغفر",
            systemImageName: "sparkles"
        )
    }
    static var shortcutTileColor: ShortcutTileColor = .navy
}
