import SwiftUI

@main
struct BabyKeysApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var lockController = LockController.shared

    var body: some Scene {
        MenuBarExtra(
            "BabyKeys",
            systemImage: lockController.isLocked ? "lock.fill" : "lock.open"
        ) {
            Text(lockController.isLocked ? "Status: Locked" : "Status: Unlocked")
                .font(.headline)
            Divider()
            Text("Hold Right ⌘ for 5s to toggle")
                .font(.caption)
                .foregroundColor(.secondary)
            Divider()
            Button("Quit BabyKeys") {
                LockController.shared.forceUnlock()
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
