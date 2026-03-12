import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    let store = AppMappingStore()
    var switcher: AppSwitcher!
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        switcher = AppSwitcher(store: store)
        KeyInterceptor.shared.onKeyPress = { [weak self] key, mods in
            self?.switcher.handleKey(key, modifiers: mods)
        }

        if PermissionHelper.isAccessibilityGranted() {
            KeyInterceptor.shared.start()
        } else {
            PermissionHelper.requestAccessibility()
            // Poll until permission is granted, then start the event tap
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                guard PermissionHelper.isAccessibilityGranted() else { return }
                timer.invalidate()
                self?.permissionTimer = nil
                KeyInterceptor.shared.start()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        KeyInterceptor.shared.stop()
    }
}
