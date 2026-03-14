# KeyGuard — Design Spec

## Purpose

KeyGuard is a macOS menu bar app that lets users lock and unlock their keyboard and touchpad with a 5-second long-press of the Right Command key. This is useful for cleaning the keyboard, preventing accidental input from pets/children, or any scenario where temporary input disabling is needed.

## Requirements

- **Lock trigger:** Hold Right Command for 5 seconds to lock all keyboard and touchpad/mouse input
- **Unlock trigger:** Hold Right Command for 5 seconds again to unlock
- **Power button:** Must remain functional (long-press for shutdown) — this works naturally since power button events are hardware-level, not CGEvents
- **No persistence:** Lock state is in-memory only; restarting the Mac always restores input
- **Lid close:** Closing the laptop lid unlocks input (subscribe to `NSWorkspace.willSleepNotification` and unlock on sleep)
- **Visual feedback:** Menu bar icon changes (lock/unlock) + macOS notification on state change
- **Accessibility permission:** Required for CGEventTap; app prompts on first launch

## Architecture

### Approach: CGEventTap

Uses `CGEvent.tapCreate()` to intercept all input events at the session level. When locked, the callback returns `nil` for all events (swallowing them). The Right Command key is always monitored for the 5-second hold pattern.

This is the same proven pattern used by KeyPilot. No root privileges needed — only Accessibility permission.

### Components

| File | Responsibility |
|------|---------------|
| `KeyGuardApp.swift` | SwiftUI entry point, `MenuBarExtra` with dynamic lock/unlock icon |
| `AppDelegate.swift` | Lifecycle management, interceptor init/teardown, permission polling, sleep/wake observer |
| `InputInterceptor.swift` | CGEventTap for global keyboard + trackpad/mouse capture |
| `LockController.swift` | Lock state machine, 5-second hold detection, state transitions |
| `PermissionHelper.swift` | Accessibility permission check and request |

### Event Tap Configuration

- **Tap type:** Session-level (`CGSessionEventTap`), at head of event chain
- **Event mask:** `keyDown`, `keyUp`, `flagsChanged`, `mouseMoved`, `leftMouseDown`, `leftMouseUp`, `leftMouseDragged`, `rightMouseDown`, `rightMouseUp`, `rightMouseDragged`, `otherMouseDown`, `otherMouseUp`, `otherMouseDragged`, `scrollWheel`, `tabletPointer`, `tabletProximity`
- Note: trackpad gesture events (pinch, rotate, swipe) are delivered as `NSEvent` gesture types which map to the mouse/scroll event types above. No separate gesture mask is needed for CGEventTap.

### Event Tap Callback Logic

The callback inspects every event and branches as follows:

```
1. If event type is `tapDisabledByTimeout`:
   → Re-enable the tap (CGEvent.tapEnable). Lock state is preserved.
   → Return nil (no event to forward).

2. If event type is `flagsChanged`:
   → Read raw flags from the event.
   → Check if Right Command bit (kNXDeviceRCmdKeyMask = 0x10) is set:
     - Bit NOW SET (was not before) = Right Cmd key-DOWN → start 5s hold timer.
     - Bit NOW CLEAR (was set before) = Right Cmd key-UP → cancel hold timer.
   → Track previous Right Cmd state in a Bool to detect transitions.
   → ALWAYS return the event (pass through). Never swallow flagsChanged
     to avoid stuck-modifier bugs in the OS.

3. If lock state is UNLOCKED:
   → Return the event (pass through).

4. If lock state is LOCKED:
   → Return nil (swallow the event).
```

Key points:
- `flagsChanged` events are **never swallowed** — they always pass through. This ensures the OS modifier state stays consistent and, critically, allows Right Command to be detected for unlocking.
- Only non-modifier events are swallowed when locked.

### 5-Second Hold Detection

1. On Right Command key-down (detected via `flagsChanged` flag transition) → start a `DispatchSourceTimer` for 5 seconds on the **main queue** (same queue as the event tap run loop, avoiding thread-safety issues with the lock state)
2. On Right Command key-up before 5s → cancel timer, no action
3. On timer fire (5s elapsed) → toggle lock state
4. **Any other key or modifier pressed during the hold** → cancel the timer (clean hold only)
5. Rapid release-and-repress of Right Command resets the timer

### Sleep/Wake Unlock

- `AppDelegate` subscribes to `NSWorkspace.willSleepNotification`
- On sleep (lid close or manual sleep) → if locked, transition to unlocked state
- This ensures input is always restored when the laptop wakes from sleep

### Lock State Notifications

- **On lock:** Menu bar icon → `lock.fill`, post notification "Keyboard & Touchpad Locked"
- **On unlock:** Menu bar icon → `lock.open`, post notification "Keyboard & Touchpad Unlocked"
- Uses `UNUserNotificationCenter` for notifications

### Safety Mechanisms

- Lock state is a `Bool` in memory — no UserDefaults, no file persistence
- **CGEventTap timeout recovery:** On `tapDisabledByTimeout`, re-enable the tap immediately. Lock state is preserved across the re-enable. The hold timer is reset (user must start a new 5s hold).
- **Sleep unlock:** Closing the lid or sleeping the Mac automatically unlocks input
- Power button is hardware-level (not intercepted by CGEventTap)
- App quit releases the event tap, restoring all input
- **Known limitation:** If the Right Command key physically breaks while locked, the only recovery is force-restart (power button long-press). This is acceptable given the no-persistence guarantee.
- **Known limitation:** VoiceOver keyboard navigation is blocked while locked. Users relying on VoiceOver should be aware that the unlock gesture is the only escape path.

## Project Structure

```
KeyGuard/
├── Makefile
├── Info.plist
├── KeyGuard.entitlements
├── docs/
│   └── design.md          ← this spec
├── Sources/KeyGuard/
│   ├── KeyGuardApp.swift
│   ├── AppDelegate.swift
│   ├── InputInterceptor.swift
│   ├── LockController.swift
│   └── PermissionHelper.swift
└── Resources/
```

## Build System

Mirrors KeyPilot's `swiftc`-based Makefile:

- `make bundle` — compile + assemble `.app` (no signing)
- `make sign` — compile + assemble + ad-hoc codesign
- `make run` — bundle + open
- `make clean` — remove build artifacts
- **Target:** `$(uname -m)-apple-macosx13.0`
- **SDK:** `xcrun --show-sdk-path`
- **Frameworks:** Cocoa, Carbon, ApplicationServices, SwiftUI, UserNotifications

## Configuration

**Info.plist:**
- `LSUIElement: true` (menu bar only, no Dock icon)
- `CFBundleIdentifier: com.keyguard.app`
- `NSAccessibilityUsageDescription: "KeyGuard needs Accessibility access to intercept keyboard and trackpad input."`

**KeyGuard.entitlements:**
- `com.apple.security.app-sandbox: false` (required for CGEventTap)

## Verification

1. `make bundle` compiles without errors
2. `make run` launches the app in the menu bar
3. Grant Accessibility permission when prompted
4. Hold Right Command for 5s → menu bar icon changes to locked, notification appears, all keyboard/trackpad input is blocked
5. Hold Right Command for 5s again → icon changes to unlocked, notification appears, input restored
6. While locked, long-press power button → Mac shows shutdown dialog (confirming hardware-level bypass)
7. While locked, force-restart → after reboot, input works normally (no persisted lock state)
8. While locked, close laptop lid → after reopening, input works normally (sleep unlocks)
