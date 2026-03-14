import Cocoa
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }

        // Subscribe to sleep for auto-unlock
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )

        if PermissionHelper.isAccessibilityGranted() {
            InputInterceptor.shared.start()
        } else {
            PermissionHelper.requestAccessibility()
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                guard PermissionHelper.isAccessibilityGranted() else { return }
                timer.invalidate()
                self?.permissionTimer = nil
                InputInterceptor.shared.start()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        InputInterceptor.shared.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func systemWillSleep(_ notification: Notification) {
        LockController.shared.forceUnlock()
    }
}
