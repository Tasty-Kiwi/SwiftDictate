import Testing
import AppKit
@testable import SwiftDictate

struct TextInsertionServiceTests {

    @Test func autoInsertDefaultsToTrue() {
        let service = TextInsertionService()
        #expect(service.autoInsert)
    }

    @Test func autoInsertCanBeToggled() {
        let service = TextInsertionService()
        service.autoInsert = false
        #expect(!service.autoInsert)

        service.autoInsert = true
        #expect(service.autoInsert)
    }

    @Test func emptyTextDoesNotThrow() async throws {
        let service = TextInsertionService()
        try await service.insertText("", autoInsert: false)
    }

    @Test func insertTextWithClipboardFallback() async throws {
        let service = TextInsertionService()
        let testString = "Hello, World!"

        try await service.insertText(testString, autoInsert: false)

        let pasteboard = NSPasteboard.general
        let content = pasteboard.string(forType: .string)

        #expect(content == testString)

        pasteboard.clearContents()
    }

    @Test func pasteFromClipboardPostsCGEvent() {
        let service = TextInsertionService()
        service.pasteFromClipboard()
    }
}
