import Foundation
import Testing
@testable import SwiftDictate

struct TextInsertionServiceTests {

    @Test func emptyTextDoesNotTouchClipboardOrPostPaste() async throws {
        let clipboard = FakeClipboard()
        var pasteCount = 0
        let service = makeService(clipboard: clipboard, performPaste: { pasteCount += 1 })

        try await service.insertText("")

        #expect(clipboard.writtenTexts.isEmpty)
        #expect(pasteCount == 0)
    }

    @Test func fallbackCopiesTextWithoutPostingPaste() async throws {
        let clipboard = FakeClipboard()
        var pasteCount = 0
        let service = makeService(
            clipboard: clipboard,
            hasFocusedApplication: false,
            performPaste: { pasteCount += 1 }
        )

        try await service.insertText("dictated text")

        #expect(clipboard.writtenTexts == ["dictated text"])
        #expect(clipboard.restoredSnapshots.isEmpty)
        #expect(pasteCount == 0)
    }

    @Test func pasteRestoresThePreviousClipboardWhenItRemainsUnchanged() async throws {
        let previous = ClipboardSnapshot(items: [["public.utf8-plain-text": Data("before".utf8)]])
        let clipboard = FakeClipboard(snapshot: previous)
        var pasteCount = 0
        let service = makeService(clipboard: clipboard, performPaste: { pasteCount += 1 })

        try await service.insertText("dictated text")

        #expect(pasteCount == 1)
        #expect(clipboard.restoredSnapshots == [previous])
    }

    @Test func pasteDoesNotOverwriteAClipboardChangeMadeWhilePasting() async throws {
        let clipboard = FakeClipboard()
        let service = makeService(clipboard: clipboard, performPaste: {
            clipboard.changeCount += 1
        })

        try await service.insertText("dictated text")

        #expect(clipboard.restoredSnapshots.isEmpty)
    }

    @Test func pasteFailureDoesNotRestoreTheClipboard() async {
        let clipboard = FakeClipboard()
        let service = makeService(clipboard: clipboard, performPaste: {
            throw TextInsertionError.insertionFailed
        })

        await #expect(throws: TextInsertionError.insertionFailed) {
            try await service.insertText("dictated text")
        }
        #expect(clipboard.restoredSnapshots.isEmpty)
    }

    private func makeService(
        clipboard: FakeClipboard,
        hasFocusedApplication: Bool = true,
        performPaste: @escaping () async throws -> Void = {}
    ) -> TextInsertionService {
        TextInsertionService(
            clipboard: clipboard,
            hasFocusedApplication: { hasFocusedApplication },
            performPaste: performPaste,
            wait: { _ in }
        )
    }
}

private final class FakeClipboard: ClipboardClient {
    var changeCount = 0
    var snapshot: ClipboardSnapshot
    private(set) var writtenTexts: [String] = []
    private(set) var restoredSnapshots: [ClipboardSnapshot] = []

    init(snapshot: ClipboardSnapshot = ClipboardSnapshot(items: [])) {
        self.snapshot = snapshot
    }

    func capture() -> ClipboardSnapshot {
        snapshot
    }

    func writeText(_ text: String) throws {
        writtenTexts.append(text)
        changeCount += 1
    }

    func restore(_ snapshot: ClipboardSnapshot) {
        restoredSnapshots.append(snapshot)
        self.snapshot = snapshot
        changeCount += 1
    }
}
