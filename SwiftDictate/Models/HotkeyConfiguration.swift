import AppKit
import CoreGraphics

struct HotkeyConfiguration: Sendable {
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags
    var requiresAccessibility: Bool { true }

    static let `default` = HotkeyConfiguration(
        keyCode: 61,
        modifiers: []
    )

    static let presetOptions: [(String, HotkeyConfiguration)] = [
        ("Right Option", HotkeyConfiguration(keyCode: 61, modifiers: [])),
        ("Right Command", HotkeyConfiguration(keyCode: 54, modifiers: [])),
        ("F5 (No Modifiers)", HotkeyConfiguration(keyCode: 96, modifiers: [])),
    ]

    var displayName: String {
        let keyName = keyCodeDisplayName(keyCode)
        if modifiers.isEmpty {
            return keyName
        }

        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("Ctrl") }
        if modifiers.contains(.option) { parts.append("Opt") }
        if modifiers.contains(.shift) { parts.append("Shift") }
        if modifiers.contains(.command) { parts.append("Cmd") }
        parts.append(keyName)
        return parts.joined(separator: "+")
    }

    private func keyCodeDisplayName(_ code: UInt16) -> String {
        switch code {
        case 61: return "Right Option"
        case 54: return "Right Command"
        case 55: return "Left Command"
        case 58: return "Left Option"
        case 59: return "Control"
        case 56: return "Left Shift"
        case 60: return "Right Shift"
        case 96: return "F5"
        case 63: return "Fn"
        case 53: return "Escape"
        default: return "Key \(code)"
        }
    }
}
