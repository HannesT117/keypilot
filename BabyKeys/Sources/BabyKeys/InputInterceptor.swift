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

        var eventMask: CGEventMask = 0
        eventMask |= CGEventMask(1) << CGEventType.keyDown.rawValue
        eventMask |= CGEventMask(1) << CGEventType.keyUp.rawValue
        eventMask |= CGEventMask(1) << CGEventType.flagsChanged.rawValue
        eventMask |= CGEventMask(1) << CGEventType.mouseMoved.rawValue
        eventMask |= CGEventMask(1) << CGEventType.leftMouseDown.rawValue
        eventMask |= CGEventMask(1) << CGEventType.leftMouseUp.rawValue
        eventMask |= CGEventMask(1) << CGEventType.leftMouseDragged.rawValue
        eventMask |= CGEventMask(1) << CGEventType.rightMouseDown.rawValue
        eventMask |= CGEventMask(1) << CGEventType.rightMouseUp.rawValue
        eventMask |= CGEventMask(1) << CGEventType.rightMouseDragged.rawValue
        eventMask |= CGEventMask(1) << CGEventType.otherMouseDown.rawValue
        eventMask |= CGEventMask(1) << CGEventType.otherMouseUp.rawValue
        eventMask |= CGEventMask(1) << CGEventType.otherMouseDragged.rawValue
        eventMask |= CGEventMask(1) << CGEventType.scrollWheel.rawValue
        eventMask |= CGEventMask(1) << CGEventType.tabletPointer.rawValue
        eventMask |= CGEventMask(1) << CGEventType.tabletProximity.rawValue

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
            print("BabyKeys: Failed to create event tap. Check Accessibility permissions.")
            return
        }

        machPort = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        runLoopSource = source
        CGEvent.tapEnable(tap: tap, enable: true)
        print("BabyKeys: Event tap started.")
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
