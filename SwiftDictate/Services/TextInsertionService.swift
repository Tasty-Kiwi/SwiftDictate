import AppKit
import Foundation
import os

enum TextInsertionError: Error, Equatable {
    case insertionFailed
    case clipboardFailed
}

struct ClipboardSnapshot: Equatable {
    let items: [[String: Data]]
}

protocol ClipboardClient {
    var changeCount: Int { get }

    func capture() -> ClipboardSnapshot
    func writeText(_ text: String) throws
    func restore(_ snapshot: ClipboardSnapshot)
}

final class TextInsertionService {
    private let clipboard: any ClipboardClient
    private let hasFocusedApplication: () -> Bool
    private let performPaste: () async throws -> Void
    private let wait: (Duration) async throws -> Void

    private let logger = Logger(
        subsystem: "net.tastykiwi.SwiftDictate",
        category: "TextInsertionService"
    )

    init(
        clipboard: any ClipboardClient = SystemClipboardClient(),
        hasFocusedApplication: @escaping () -> Bool = {
            NSWorkspace.shared.runningApplications.contains(where: \.isActive)
        },
        performPaste: @escaping () async throws -> Void = {
            try await TextInsertionService.postPasteCommand()
        },
        wait: @escaping (Duration) async throws -> Void = { duration in
            try await Task.sleep(for: duration)
        }
    ) {
        self.clipboard = clipboard
        self.hasFocusedApplication = hasFocusedApplication
        self.performPaste = performPaste
        self.wait = wait
    }

    func insertText(
        _ text: String,
        autoInsert: Bool = true,
        restoreClipboardAfterPaste: Bool = true
    ) async throws {
        guard !text.isEmpty else { return }

        guard autoInsert, hasFocusedApplication() else {
            try copyToClipboard(text)
            logger.debug("Text copied to clipboard as fallback")
            return
        }

        try await pasteTextViaClipboard(
            text,
            restoreClipboardAfterPaste: restoreClipboardAfterPaste
        )
        logger.debug("Text inserted via clipboard paste into focused app")
    }

    private func pasteTextViaClipboard(
        _ text: String,
        restoreClipboardAfterPaste: Bool
    ) async throws {
        let snapshot = clipboard.capture()
        try copyToClipboard(text)
        let insertedChangeCount = clipboard.changeCount

        try await wait(.milliseconds(50))
        try await performPaste()
        try await wait(.milliseconds(500))

        // Do not overwrite a clipboard change made by the user or receiving app
        // while the paste command was in flight.
        if restoreClipboardAfterPaste, clipboard.changeCount == insertedChangeCount {
            clipboard.restore(snapshot)
        }
    }

    private func copyToClipboard(_ text: String) throws {
        try clipboard.writeText(text)
    }

    private static func postPasteCommand() async throws {
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

private final class SystemClipboardClient: ClipboardClient {
    private var pasteboard: NSPasteboard { .general }

    var changeCount: Int { pasteboard.changeCount }

    func capture() -> ClipboardSnapshot {
        let items = pasteboard.pasteboardItems?.map { item in
            item.types.reduce(into: [String: Data]()) { result, type in
                result[type.rawValue] = item.data(forType: type)
            }
        } ?? []

        return ClipboardSnapshot(items: items)
    }

    func writeText(_ text: String) throws {
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw TextInsertionError.clipboardFailed
        }
    }

    func restore(_ snapshot: ClipboardSnapshot) {
        pasteboard.clearContents()

        let restoredItems = snapshot.items.map { itemData in
            let item = NSPasteboardItem()
            for (rawType, data) in itemData {
                item.setData(data, forType: NSPasteboard.PasteboardType(rawValue: rawType))
            }
            return item
        }

        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
    }
}
