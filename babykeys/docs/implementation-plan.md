# KeyGuard Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar app that locks/unlocks keyboard and touchpad input via a 5-second Right Command hold.

**Architecture:** CGEventTap intercepts all input events. A LockController state machine manages lock state and 5-second hold detection. AppDelegate handles lifecycle, permissions, and sleep-unlock. SwiftUI MenuBarExtra provides the UI.

**Tech Stack:** Swift, SwiftUI, CGEvent (Quartz), Carbon.HIToolbox, UserNotifications, `swiftc` via Makefile

**Spec:** `KeyGuard/docs/design.md`

**Note:** No automated tests — same constraint as KeyPilot (CGEventTap requires Accessibility permission and global event taps). Verification is manual per the spec's verification section.

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `KeyGuard/Makefile` | Create | Build system (mirrors `Makefile` from KeyPilot) |
| `KeyGuard/Info.plist` | Create | App metadata (mirrors `Info.plist` from KeyPilot) |
| `KeyGuard/KeyGuard.entitlements` | Create | Entitlements (mirrors `KeyPilot.entitlements`) |
| `KeyGuard/Sources/KeyGuard/PermissionHelper.swift` | Create | Accessibility permission check/request (same as `Sources/KeyPilot/PermissionHelper.swift`) |
| `KeyGuard/Sources/KeyGuard/LockController.swift` | Create | Lock state machine + 5s hold timer |
| `KeyGuard/Sources/KeyGuard/InputInterceptor.swift` | Create | CGEventTap — all input events, callback with lock logic (adapted from `Sources/KeyPilot/KeyInterceptor.swift`) |
| `KeyGuard/Sources/KeyGuard/AppDelegate.swift` | Create | Lifecycle, permission polling, sleep observer (adapted from `Sources/KeyPilot/AppDelegate.swift`) |
| `KeyGuard/Sources/KeyGuard/KeyGuardApp.swift` | Create | SwiftUI entry point + MenuBarExtra (adapted from `Sources/KeyPilot/KeyPilotApp.swift`) |

---

## Chunk 1: Project Scaffolding

### Task 1: Create build infrastructure

**Files:**
- Create: `KeyGuard/Makefile`
- Create: `KeyGuard/Info.plist`
- Create: `KeyGuard/KeyGuard.entitlements`

- [ ] **Step 1: Create Makefile**

Adapted from `Makefile` (KeyPilot root). Key differences: source path is `Sources/KeyGuard/`, adds `UserNotifications` framework, no app icon copy (uses SF Symbols).

```makefile
SOURCES = $(wildcard Sources/KeyGuard/*.swift)
APP_NAME = KeyGuard
APP_BUNDLE = $(APP_NAME).app
SDK = $(shell xcrun --show-sdk-path)
TARGET = $(shell uname -m)-apple-macosx13.0

.PHONY: build bundle sign run clean

build: $(APP_NAME)

$(APP_NAME): $(SOURCES)
	swiftc \
		-target $(TARGET) \
		-sdk $(SDK) \
		-framework Cocoa \
		-framework Carbon \
		-framework ApplicationServices \
		-framework SwiftUI \
		-framework UserNotifications \
		-o $(APP_NAME) \
		$(SOURCES)

bundle: build
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	cp $(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp Info.plist $(APP_BUNDLE)/Contents/

sign: bundle
	codesign --force --deep --sign - \
		--entitlements KeyGuard.entitlements \
		$(APP_BUNDLE)

run: bundle
	open $(APP_BUNDLE)

clean:
	rm -rf $(APP_NAME) $(APP_BUNDLE)
```

- [ ] **Step 2: Create Info.plist**

Adapted from `Info.plist` (KeyPilot root). Changes: bundle name/ID/executable → KeyGuard, no icon file, updated accessibility description.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>KeyGuard</string>
	<key>CFBundleDisplayName</key>
	<string>KeyGuard</string>
	<key>CFBundleIdentifier</key>
	<string>com.keyguard.app</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleExecutable</key>
	<string>KeyGuard</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSAccessibilityUsageDescription</key>
	<string>KeyGuard needs Accessibility access to intercept keyboard and trackpad input.</string>
</dict>
</plist>
```

- [ ] **Step 3: Create KeyGuard.entitlements**

Identical to `KeyPilot.entitlements`.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<false/>
</dict>
</plist>
```

- [ ] **Step 4: Create empty source directory**

```bash
mkdir -p KeyGuard/Sources/KeyGuard
```

- [ ] **Step 5: Commit scaffolding**

```bash
cd KeyGuard && git add Makefile Info.plist KeyGuard.entitlements Sources/ && git commit -m "feat(keyguard): add project scaffolding"
```

---

## Chunk 2: Core Logic

### Task 2: Create PermissionHelper

**Files:**
- Create: `KeyGuard/Sources/KeyGuard/PermissionHelper.swift`
- Reference: `Sources/KeyPilot/PermissionHelper.swift`

- [ ] **Step 1: Write PermissionHelper.swift**

Identical to KeyPilot's `PermissionHelper.swift`.

```swift
import ApplicationServices
import CoreGraphics

enum PermissionHelper {
    static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibility() {
        let options =
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
```

- [ ] **Step 2: Commit**

```bash
cd KeyGuard && git add Sources/KeyGuard/PermissionHelper.swift && git commit -m "feat(keyguard): add PermissionHelper"
```

### Task 3: Create LockController

**Files:**
- Create: `KeyGuard/Sources/KeyGuard/LockController.swift`

This is the state machine. It owns the lock `Bool`, the 5-second hold timer, and publishes state changes for the UI.

- [ ] **Step 1: Write LockController.swift**

```swift
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
        print("KeyGuard: \(isLocked ? "LOCKED" : "UNLOCKED")")
    }

    private func postNotification(locked: Bool) {
        let content = UNMutableNotificationContent()
        content.title = "KeyGuard"
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
```

- [ ] **Step 2: Commit**

```bash
cd KeyGuard && git add Sources/KeyGuard/LockController.swift && git commit -m "feat(keyguard): add LockController state machine"
```

### Task 4: Create InputInterceptor

**Files:**
- Create: `KeyGuard/Sources/KeyGuard/InputInterceptor.swift`
- Reference: `Sources/KeyPilot/KeyInterceptor.swift`

Adapted from KeyPilot's `KeyInterceptor`. Key differences: intercepts ALL event types (not just keyDown), callback logic branches per the spec's pseudocode, delegates to LockController for state.

- [ ] **Step 1: Write InputInterceptor.swift**

```swift
import Cocoa
import Carbon.HIToolbox

private let kNXDeviceRCmdKeyMask: UInt64 = 0x10

/// CGEventTap callback. Runs on the main run loop (same thread as the run loop source).
/// All LockController calls are synchronous — no DispatchQueue.main.async needed.
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let interceptor = Unmanaged<InputInterceptor>.fromOpaque(userInfo).takeUnretainedValue()

    // 1. Re-enable tap if disabled by timeout. Lock state preserved, hold state reset.
    if type == .tapDisabledByTimeout {
        if let port = interceptor.machPort {
            CGEvent.tapEnable(tap: port, enable: true)
        }
        LockController.shared.resetHoldState()
        return Unmanaged.passUnretained(event)
    }

    // 2. flagsChanged: detect Right Cmd transitions, ALWAYS pass through.
    if type == .flagsChanged {
        let flags = event.flags.rawValue
        let rightCmdDown = (flags & kNXDeviceRCmdKeyMask) != 0
        LockController.shared.handleFlagsChanged(rightCmdDown: rightCmdDown, rawFlags: flags)
        return Unmanaged.passUnretained(event)
    }

    // For non-flagsChanged events: cancel hold timer if a key is pressed during hold
    if type == .keyDown || type == .keyUp {
        LockController.shared.cancelHoldIfActive()
    }

    // 3. Unlocked: pass through.
    if !LockController.shared.isLocked {
        return Unmanaged.passUnretained(event)
    }

    // 4. Locked: swallow.
    return nil
}

class InputInterceptor {
    static let shared = InputInterceptor()

    fileprivate var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        guard machPort == nil else { return }

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.mouseMoved.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.rightMouseUp.rawValue)
            | (1 << CGEventType.rightMouseDragged.rawValue)
            | (1 << CGEventType.otherMouseDown.rawValue)
            | (1 << CGEventType.otherMouseUp.rawValue)
            | (1 << CGEventType.otherMouseDragged.rawValue)
            | (1 << CGEventType.scrollWheel.rawValue)
            | (1 << CGEventType.tabletPointer.rawValue)
            | (1 << CGEventType.tabletProximity.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: eventTapCallback,
                userInfo: refcon
            )
        else {
            print("KeyGuard: Failed to create event tap. Check Accessibility permissions.")
            return
        }

        machPort = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        runLoopSource = source
        CGEvent.tapEnable(tap: tap, enable: true)
        print("KeyGuard: Event tap started.")
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let port = machPort {
            CGEvent.tapEnable(tap: port, enable: false)
            machPort = nil
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
cd KeyGuard && git add Sources/KeyGuard/InputInterceptor.swift && git commit -m "feat(keyguard): add InputInterceptor with CGEventTap"
```

---

## Chunk 3: App Shell and Integration

### Task 5: Create AppDelegate

**Files:**
- Create: `KeyGuard/Sources/KeyGuard/AppDelegate.swift`
- Reference: `Sources/KeyPilot/AppDelegate.swift`

Adapted from KeyPilot. Adds sleep notification observer for auto-unlock. Requests notification permission.

- [ ] **Step 1: Write AppDelegate.swift**

```swift
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
```

- [ ] **Step 2: Commit**

```bash
cd KeyGuard && git add Sources/KeyGuard/AppDelegate.swift && git commit -m "feat(keyguard): add AppDelegate with sleep-unlock"
```

### Task 6: Create KeyGuardApp (SwiftUI entry point)

**Files:**
- Create: `KeyGuard/Sources/KeyGuard/KeyGuardApp.swift`
- Reference: `Sources/KeyPilot/KeyPilotApp.swift`

Simpler than KeyPilot — no settings window needed. Menu bar shows dynamic lock/unlock icon.

- [ ] **Step 1: Write KeyGuardApp.swift**

```swift
import SwiftUI

@main
struct KeyGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var lockController = LockController.shared

    var body: some Scene {
        MenuBarExtra(
            "KeyGuard",
            systemImage: lockController.isLocked ? "lock.fill" : "lock.open"
        ) {
            Text(lockController.isLocked ? "Status: Locked" : "Status: Unlocked")
                .font(.headline)
            Divider()
            Text("Hold Right ⌘ for 5s to toggle")
                .font(.caption)
                .foregroundColor(.secondary)
            Divider()
            Button("Quit KeyGuard") {
                LockController.shared.forceUnlock()
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
cd KeyGuard && git add Sources/KeyGuard/KeyGuardApp.swift && git commit -m "feat(keyguard): add KeyGuardApp SwiftUI entry point"
```

---

## Chunk 4: Build and Verify

### Task 7: Build and fix any compilation errors

- [ ] **Step 1: Build the app**

```bash
cd KeyGuard && make bundle
```

Expected: compiles without errors, produces `KeyGuard.app`.

- [ ] **Step 2: Fix any compilation errors**

If compilation fails, fix errors and rebuild. Common issues: missing imports, type mismatches.

- [ ] **Step 3: Commit the final working build**

```bash
cd KeyGuard && git add -A && git commit -m "feat(keyguard): KeyGuard v1 — keyboard and touchpad locker for macOS"
```

### Task 8: Manual verification

Run through the verification checklist from `KeyGuard/docs/design.md`:

- [ ] **Step 1:** `cd KeyGuard && make run` — app appears in menu bar with unlock icon
- [ ] **Step 2:** Grant Accessibility permission when prompted
- [ ] **Step 3:** Hold Right Command for 5s → icon changes to locked, notification appears
- [ ] **Step 4:** Type on keyboard / move trackpad → no input registered
- [ ] **Step 5:** Hold Right Command for 5s → icon changes to unlocked, notification appears, input restored
- [ ] **Step 6:** While locked, close laptop lid → after reopening, input works (sleep unlocks)
