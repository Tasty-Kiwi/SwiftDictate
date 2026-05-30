import CoreGraphics
import AppKit
import Foundation

enum CGEventHelperError: Error {
    case eventCreationFailed
    case postFailed
}

enum CGEventHelpers {
    static func simulateKeyPress(_ keyCode: CGKeyCode, flags: CGEventFlags = []) throws {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            throw CGEventHelperError.eventCreationFailed
        }
        event.flags = flags
        event.post(tap: .cgAnnotatedSessionEventTap)
    }

    static func simulateKeyRelease(_ keyCode: CGKeyCode, flags: CGEventFlags = []) throws {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            throw CGEventHelperError.eventCreationFailed
        }
        event.flags = flags
        event.post(tap: .cgAnnotatedSessionEventTap)
    }

    static func typeText(_ text: String) throws {
        for character in text {
            try typeCharacter(character)
        }
    }

    static func typeCharacter(_ character: Character) throws {
        let string = String(character)

        guard let eventSource = CGEventSource(stateID: .combinedSessionState) else {
            throw CGEventHelperError.eventCreationFailed
        }

        let charArray = Array(string.utf16)

        if charArray.isEmpty { return }

        var event = CGEvent(
            keyboardEventSource: eventSource,
            virtualKey: 0,
            keyDown: true
        )
        event?.keyboardSetUnicodeString(
            stringLength: charArray.count,
            unicodeString: charArray
        )
        event?.post(tap: .cghidEventTap)

        usleep(100)

        event = CGEvent(
            keyboardEventSource: eventSource,
            virtualKey: 0,
            keyDown: false
        )
        event?.post(tap: .cghidEventTap)

        usleep(100)
    }

    static func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)

        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand
        vDown?.post(tap: .cghidEventTap)

        usleep(10_000)

        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand
        vUp?.post(tap: .cghidEventTap)
    }

    static func getFocusedAppPID() -> pid_t {
        var focusedApp: NSRunningApplication?
        let apps = NSWorkspace.shared.runningApplications
        focusedApp = apps.first { $0.isActive }
        return focusedApp?.processIdentifier ?? 0
    }
}
