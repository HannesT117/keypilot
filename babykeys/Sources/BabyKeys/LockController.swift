import Foundation
import Cocoa
import UserNotifications

class LockController: ObservableObject {
    static let shared = LockController()

    @Published private(set) var isLocked = false

    private var holdTimer: DispatchSourceTimer?
    private var wasRightCmdDown = false
    private var previousModifierFlags: UInt64 = 0

    /// Called by InputInterceptor on every flagsChanged event (synchronously from the callback).
    /// Detects Right Cmd transitions and other-modifier cancellation.
    func handleFlagsChanged(rightCmdDown: Bool, rawFlags: UInt64) {
        // Check if any non-Right-Cmd modifier changed (Shift, Option, Control, Left Cmd).
        // If so, cancel any active hold — spec requires "clean hold only".
        let modifierMask: UInt64 = UInt64(CGEventFlags.maskShift.rawValue)
            | UInt64(CGEventFlags.maskAlternate.rawValue)
            | UInt64(CGEventFlags.maskControl.rawValue)
        let otherModsChanged = (rawFlags & modifierMask) != (previousModifierFlags & modifierMask)
        if otherModsChanged {
            cancelHoldTimer()
        }
        previousModifierFlags = rawFlags

        if rightCmdDown && !wasRightCmdDown {
            // Right Cmd key-DOWN transition → start hold timer
            startHoldTimer()
        } else if !rightCmdDown && wasRightCmdDown {
            // Right Cmd key-UP transition → cancel hold timer
            cancelHoldTimer()
        }
        wasRightCmdDown = rightCmdDown
    }

    /// Called by InputInterceptor when any non-modifier key is pressed during hold.
    func cancelHoldIfActive() {
        cancelHoldTimer()
    }

    /// Called on tapDisabledByTimeout — reset hold state so user must start fresh.
    func resetHoldState() {
        cancelHoldTimer()
        wasRightCmdDown = false
    }

    /// Called by AppDelegate on sleep to force-unlock.
    func forceUnlock() {
        guard isLocked else { return }
        isLocked = false
        cancelHoldTimer()
        wasRightCmdDown = false
        postNotification(locked: false)
    }

    private func startHoldTimer() {
        cancelHoldTimer()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 5.0)
        timer.setEventHandler { [weak self] in
            self?.toggleLock()
        }
        timer.resume()
        holdTimer = timer
    }

    private func cancelHoldTimer() {
        holdTimer?.cancel()
        holdTimer = nil
    }

    private func toggleLock() {
        isLocked.toggle()
        cancelHoldTimer()
        // Reset wasRightCmdDown so the key-up after toggle is a no-op.
        // This relies on cancelHoldTimer() being idempotent.
        wasRightCmdDown = false
        postNotification(locked: isLocked)
        print("BabyKeys: \(isLocked ? "LOCKED" : "UNLOCKED")")
    }

    private func postNotification(locked: Bool) {
        let content = UNMutableNotificationContent()
        content.title = "BabyKeys"
        content.body = locked
            ? "Keyboard & Touchpad Locked"
            : "Keyboard & Touchpad Unlocked"

        let request = UNNotificationRequest(
            identifier: "keyguard-state",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
