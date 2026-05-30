import AppKit
import Foundation
import os

enum TextInsertionError: Error {
    case noFocusedApplication
    case insertionFailed
    case clipboardFailed
}

final class TextInsertionService {
    private let logger = Logger(
        subsystem: "net.tastykiwi.SwiftDictate",
        category: "TextInsertionService"
    )

    var autoInsert: Bool = true

    func insertText(_ text: String, autoInsert: Bool = true) async throws {
        guard !text.isEmpty else { return }

        if autoInsert {
            let focusedApp = getFocusedApp()
            if focusedApp != nil {
                try await typeTextViaCGEvent(text)
                logger.debug("Text inserted via CGEvent into focused app")
                return
            }
        }

        try await copyToClipboard(text)
        logger.debug("Text copied to clipboard as fallback")
    }

    private func getFocusedApp() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.isActive }
    }

    private func typeTextViaCGEvent(_ text: String) async throws {
        guard let eventSource = CGEventSource(stateID: .combinedSessionState) else {
            throw TextInsertionError.insertionFailed
        }

        for character in text {
            let charString = String(character)
            let utf16Chars = Array(charString.utf16)
            guard !utf16Chars.isEmpty else { continue }

            guard let keyDownEvent = CGEvent(
                keyboardEventSource: eventSource,
                virtualKey: 0,
                keyDown: true
            ) else {
                throw TextInsertionError.insertionFailed
            }

            keyDownEvent.keyboardSetUnicodeString(
                stringLength: utf16Chars.count,
                unicodeString: utf16Chars
            )
            keyDownEvent.post(tap: .cghidEventTap)

            try await Task.sleep(for: .milliseconds(1))

            guard let keyUpEvent = CGEvent(
                keyboardEventSource: eventSource,
                virtualKey: 0,
                keyDown: false
            ) else {
                throw TextInsertionError.insertionFailed
            }

            keyUpEvent.post(tap: .cghidEventTap)

            try await Task.sleep(for: .milliseconds(1))
        }
    }

    private func copyToClipboard(_ text: String) async throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        guard pasteboard.setString(text, forType: .string) else {
            throw TextInsertionError.clipboardFailed
        }
    }

    func pasteFromClipboard() {
        let source = CGEventSource(stateID: .combinedSessionState)

        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        cmdDown?.flags = .maskCommand
        cmdDown?.post(tap: .cghidEventTap)

        usleep(10_000)

        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        cmdUp?.flags = .maskCommand
        cmdUp?.post(tap: .cghidEventTap)
    }
}
