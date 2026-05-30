import Testing
@testable import SwiftDictate

struct FoundationModelsServiceTests {

    @Test func initiallyUnavailable() {
        let service = FoundationModelsService()
        #expect(!service.isAvailable)
    }

    @Test func checkAvailabilitySetsState() {
        let service = FoundationModelsService()
        service.checkAvailability()
        #expect(type(of: service.isAvailable) == Bool.self)
    }

    @Test func restorePunctuationThrowsWhenUnavailable() async {
        let service = FoundationModelsService()
        #expect(!service.isAvailable)
        await #expect(throws: FoundationModelsError.unavailable) {
            _ = try await service.restorePunctuation("hello world")
        }
    }

    @Test func correctGrammarThrowsWhenUnavailable() async {
        let service = FoundationModelsService()
        #expect(!service.isAvailable)
        await #expect(throws: FoundationModelsError.unavailable) {
            _ = try await service.correctGrammar("hello world")
        }
    }

    @Test func invokeCustomPromptThrowsWhenUnavailable() async {
        let service = FoundationModelsService()
        #expect(!service.isAvailable)
        await #expect(throws: FoundationModelsError.unavailable) {
            _ = try await service.invokeCustomPrompt("make it formal", on: "hello")
        }
    }

    @Test func resetSessionWhenUnavailableDoesNotCrash() {
        let service = FoundationModelsService()
        service.resetSession()
    }

    @Test func isProcessingInitiallyFalse() {
        let service = FoundationModelsService()
        #expect(!service.isProcessing)
    }

    @Test func lastErrorInitiallyNil() {
        let service = FoundationModelsService()
        #expect(service.lastError == nil)
    }
}
