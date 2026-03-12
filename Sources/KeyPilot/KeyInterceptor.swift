import Cocoa
import Carbon.HIToolbox

// NX_DEVICERCMDKEYMASK from IOKit/IOLLEvent.h (0x08 = left cmd, 0x10 = right cmd)
private let kNXDeviceRCmdKeyMask: UInt64 = 0x10

struct KeyModifiers: OptionSet {
    let rawValue: UInt
    static let rightCommand = KeyModifiers(rawValue: 1 << 0)
    static let option = KeyModifiers(rawValue: 1 << 1)
}

// Static keycode-to-character map (QWERTY layout)
private let keyCodeMap: [Int64: Character] = [
    0x00: "a", 0x0B: "b", 0x08: "c", 0x02: "d", 0x0E: "e",
    0x03: "f", 0x05: "g", 0x04: "h", 0x22: "i", 0x26: "j",
    0x28: "k", 0x25: "l", 0x2E: "m", 0x2D: "n", 0x1F: "o",
    0x23: "p", 0x0C: "q", 0x0F: "r", 0x01: "s", 0x11: "t",
    0x20: "u", 0x09: "v", 0x0D: "w", 0x07: "x", 0x10: "y",
    0x06: "z",
]

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }

    // Re-enable tap if it was disabled by timeout
    if type == .tapDisabledByTimeout {
        let interceptor = Unmanaged<KeyInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
        if let port = interceptor.machPort {
            CGEvent.tapEnable(tap: port, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown else {
        return Unmanaged.passUnretained(event)
    }

    let flags = event.flags.rawValue
    let isCmd = (flags & UInt64(CGEventFlags.maskCommand.rawValue)) != 0
    let isRightCmd = (flags & kNXDeviceRCmdKeyMask) != 0

    guard isCmd && isRightCmd else {
        return Unmanaged.passUnretained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    guard let char = keyCodeMap[keyCode] else {
        return Unmanaged.passUnretained(event)
    }

    let isOption = (flags & UInt64(CGEventFlags.maskAlternate.rawValue)) != 0
    var mods: KeyModifiers = [.rightCommand]
    if isOption { mods.insert(.option) }

    let interceptor = Unmanaged<KeyInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
    DispatchQueue.main.async {
        interceptor.onKeyPress?(char, mods)
    }

    // Swallow the event so it doesn't type into the focused app
    return nil
}

class KeyInterceptor {
    static let shared = KeyInterceptor()

    var onKeyPress: ((Character, KeyModifiers) -> Void)?
    fileprivate var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        guard machPort == nil else { return }  // Already running

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

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
            print("KeyPilot: Failed to create event tap. Check Accessibility permissions.")
            return
        }

        machPort = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        runLoopSource = source
        CGEvent.tapEnable(tap: tap, enable: true)
        print("KeyPilot: Event tap started.")
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
