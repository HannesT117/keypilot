import SwiftUI

@main
struct KeyPilotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("KeyPilot", systemImage: "command.circle") {
            Button("Settings...") {
                if #available(macOS 14.0, *) {
                    NSApp.activate()
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                }
                SettingsWindowController.shared.showWindow(store: appDelegate.store)
            }
            .keyboardShortcut(",")
            Divider()
            Button("Quit KeyPilot") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

// Standalone settings window since SwiftUI Settings scene requires App Store entitlements
class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func showWindow(store: AppMappingStore) {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsView(store: store)
        let hostingView = NSHostingView(rootView: settingsView)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 380),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "KeyPilot Settings"
        win.contentView = hostingView
        win.center()
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)

        self.window = win
    }
}
