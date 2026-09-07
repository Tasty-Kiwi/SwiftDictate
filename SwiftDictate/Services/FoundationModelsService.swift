import Foundation
import os

#if canImport(FoundationModels)
import FoundationModels
#endif

enum FoundationModelsError: Error, Equatable {
    case unavailable
    case generationFailed
    case contextWindowExceeded
    case unsupportedLanguage
}

@Observable
final class FoundationModelsService {
    var isAvailable = false

    private let logger = Logger(
        subsystem: "net.tastykiwi.SwiftDictate",
        category: "FoundationModels"
    )

    #if canImport(FoundationModels)
    private var session: LanguageModelSession?
    #endif

    func checkAvailability() {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            isAvailable = true
            logger.info("FoundationModels available — Apple Intelligence is enabled")
        case .unavailable(let reason):
            isAvailable = false
            logger.warning("FoundationModels unavailable: \(String(describing: reason))")
        }
        #else
        isAvailable = false
        logger.warning("FoundationModels framework not importable")
        #endif
    }

    func restorePunctuation(_ text: String) async throws -> String {
        try await generate(
            "Add proper punctuation to this transcript. Only return the punctuated text without any additional explanation:\n\n\(text)",
            preservingEmptyInput: text
        )
    }

    func correctGrammar(_ text: String) async throws -> String {
        try await generate(
            "Fix any grammar errors in this text. Only return the corrected text without any additional explanation:\n\n\(text)",
            preservingEmptyInput: text
        )
    }

    func cleanupTranscript(_ text: String) async throws -> String {
        try await generate(
            """
                Clean up this dictation transcript. Follow these rules strictly:
                1. Delete ALL filler words and hesitation: um, uh, er, like, you know, sort of, kind of, I mean, basically, literally, well, so, right, actually, just, anyway, anyways
                2. When the speaker says something and then corrects themselves (e.g., "The car is red. Oh, never mind. Actually it's blue. Wait, I mean green!"), OUTPUT ONLY THE FINAL CORRECTION: "The car is green." Delete the entire correction chain — every "actually", "never mind", "wait", "I mean" — and all content before the final statement.
                3. Remove repeated words (e.g., "very very very good" → "very good")
                4. Fix obvious speech-recognition errors using context (e.g., "dictive" → "dictate", "Swift Voice" → "SwiftDictate")
                5. Preserve meaning and tone. ADD NOTHING new. OUTPUT ONLY the cleaned text, no commentary:\n\n\(text)
                """,
            preservingEmptyInput: text
        )
    }

    func resetSession() {
        #if canImport(FoundationModels)
        session = nil
        #endif
    }

    private func generate(_ prompt: String, preservingEmptyInput text: String) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text }
        guard isAvailable else { throw FoundationModelsError.unavailable }

        #if canImport(FoundationModels)
        if session == nil {
            session = createNewSession()
        }
        guard let session else { throw FoundationModelsError.unavailable }

        do {
            return try await session.respond(to: prompt).content
        } catch let error as LanguageModelSession.GenerationError {
            logger.error("Foundation Models generation failed: \(String(describing: error))")
            throw mapGenerationError(error)
        } catch {
            logger.error("Foundation Models generation failed: \(error.localizedDescription)")
            throw FoundationModelsError.generationFailed
        }
        #else
        throw FoundationModelsError.unavailable
        #endif
    }

    #if canImport(FoundationModels)
    private func mapGenerationError(_ error: LanguageModelSession.GenerationError) -> FoundationModelsError {
        switch error {
        case .exceededContextWindowSize:
            session = createNewSession()
            return .contextWindowExceeded
        case .unsupportedLanguageOrLocale:
            return .unsupportedLanguage
        case .assetsUnavailable:
            return .unavailable
        case .guardrailViolation, .unsupportedGuide, .decodingFailure, .rateLimited,
                .concurrentRequests, .refusal:
            return .generationFailed
        @unknown default:
            return .generationFailed
        }
    }

    private func createNewSession() -> LanguageModelSession {
        LanguageModelSession(
            instructions: """
                You are an assistant that improves speech-to-text transcripts. \
                Restore punctuation, correct grammar, and make the text clear \
                and readable. Preserve the original meaning. Do not add \
                information not present in the original text. Only return \
                the corrected text without any introductory or concluding remarks.
                """
        )
    }
    #endif
}
