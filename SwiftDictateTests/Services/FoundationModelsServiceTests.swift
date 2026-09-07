import Testing
@testable import SwiftDictate

struct FoundationModelsServiceTests {

    @Test func emptyInputBypassesModelAvailability() async throws {
        let service = FoundationModelsService()

        #expect(try await service.restorePunctuation("   ") == "   ")
        #expect(try await service.correctGrammar("\n") == "\n")
        #expect(try await service.cleanupTranscript("") == "")
    }

    @Test func nonEmptyInputReportsUnavailableUntilAvailabilityIsChecked() async {
        let service = FoundationModelsService()

        await #expect(throws: FoundationModelsError.unavailable) {
            _ = try await service.cleanupTranscript("hello world")
        }
    }
}
