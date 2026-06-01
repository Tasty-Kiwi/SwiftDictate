import AppKit
import Foundation
import os

enum TextInsertionError: Error {
    case noFocusedApplication
    case insertionFailed
    case clipboardFailed
}

final class TextInsertionService {
    private struct PasteboardSnapshot {
        let items: [[NSPasteboard.PasteboardType: Data]]
    }

    private let logger = Logger(
        subsystem: "net.tastykiwi.SwiftDictate",
        category: "TextInsertionService"
    )

    var autoInsert: Bool = true

    func insertText(
        _ text: String,
        autoInsert: Bool = true,
        clearClipboardAfterPaste: Bool = true
    ) async throws {
        guard !text.isEmpty else { return }

        if autoInsert {
            let focusedApp = getFocusedApp()
            if focusedApp != nil {
                try await pasteTextViaClipboard(
                    text,
                    clearClipboardAfterPaste: clearClipboardAfterPaste
                )
                logger.debug("Text inserted via clipboard paste into focused app")
                return
            }
        }

        try await copyToClipboard(text)
        logger.debug("Text copied to clipboard as fallback")
    }

    private func getFocusedApp() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.isActive }
    }

    private func pasteTextViaClipboard(
        _ text: String,
        clearClipboardAfterPaste: Bool
    ) async throws {
        let snapshot = capturePasteboard()

        try await copyToClipboard(text)
        try await Task.sleep(for: .milliseconds(50))
        try await pasteFromClipboard()
        try await Task.sleep(for: .milliseconds(500))

        if clearClipboardAfterPaste {
            restorePasteboard(snapshot)
        }
    }

    private func capturePasteboard() -> PasteboardSnapshot {
        let pasteboard = NSPasteboard.general
        let items = pasteboard.pasteboardItems?.map { item in
            item.types.reduce(into: [NSPasteboard.PasteboardType: Data]()) { result, type in
                result[type] = item.data(forType: type)
            }
        } ?? []

        return PasteboardSnapshot(items: items)
    }

    private func restorePasteboard(_ snapshot: PasteboardSnapshot) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let restoredItems = snapshot.items.map { itemData in
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            return item
        }

        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
    }

    private func copyToClipboard(_ text: String) async throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        guard pasteboard.setString(text, forType: .string) else {
            throw TextInsertionError.clipboardFailed
        }
    }

    func pasteFromClipboard() async throws {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true),
              let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false),
              let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) else {
            throw TextInsertionError.insertionFailed
        }

        commandDown.flags = .maskCommand
        vDown.flags = .maskCommand
        vUp.flags = .maskCommand
        commandUp.flags = []

        commandDown.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(10))
        vDown.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(10))
        vUp.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(10))
        commandUp.post(tap: .cghidEventTap)
    }
}
