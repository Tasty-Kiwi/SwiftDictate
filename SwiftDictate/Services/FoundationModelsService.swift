import Foundation
import os

#if canImport(FoundationModels)
import FoundationModels
#endif

enum FoundationModelsError: Error, Equatable {
    case unavailable
    case modelError(String)
    case generationFailed
    case contextWindowExceeded
    case unsupportedLanguage
}

@Observable
final class FoundationModelsService {
    var isAvailable = false
    var isProcessing = false
    var lastError: String?

    private let logger = Logger(
        subsystem: "net.tastykiwi.SwiftDictate",
        category: "FoundationModels"
    )

    private var unavailableReason: String?

    #if canImport(FoundationModels)
    private var session: LanguageModelSession?
    #endif

    func checkAvailability() {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            isAvailable = true
            unavailableReason = nil
            logger.info("FoundationModels available — Apple Intelligence is enabled")
        case .unavailable(let reason):
            isAvailable = false
            unavailableReason = String(describing: reason)
            logger.warning("FoundationModels unavailable: \(String(describing: reason))")
        }
        #else
        isAvailable = false
        unavailableReason = "FoundationModels framework is not available in this SDK."
        logger.warning("FoundationModels framework not importable")
        #endif
    }

    func restorePunctuation(_ text: String) async throws -> String {
        guard isAvailable else { throw FoundationModelsError.unavailable }

        #if canImport(FoundationModels)
        ensureSession()
        guard let session else { throw FoundationModelsError.unavailable }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let response = try await session.respond(
                to: "Add proper punctuation to this transcript. Only return the punctuated text without any additional explanation:\n\n\(text)"
            )
            return response.content
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                self.session = createNewSession()
                throw FoundationModelsError.contextWindowExceeded
            case .unsupportedLanguageOrLocale:
                throw FoundationModelsError.unsupportedLanguage
            case .assetsUnavailable:
                throw FoundationModelsError.unavailable
            case .guardrailViolation:
                throw FoundationModelsError.generationFailed
            case .unsupportedGuide:
                throw FoundationModelsError.generationFailed
            case .decodingFailure:
                throw FoundationModelsError.generationFailed
            case .rateLimited:
                throw FoundationModelsError.generationFailed
            case .concurrentRequests:
                throw FoundationModelsError.generationFailed
            case .refusal:
                throw FoundationModelsError.generationFailed
            @unknown default:
                throw FoundationModelsError.generationFailed
            }
        } catch {
            throw FoundationModelsError.modelError(error.localizedDescription)
        }
        #else
        throw FoundationModelsError.unavailable
        #endif
    }

    func correctGrammar(_ text: String) async throws -> String {
        guard isAvailable else { throw FoundationModelsError.unavailable }

        #if canImport(FoundationModels)
        ensureSession()
        guard let session else { throw FoundationModelsError.unavailable }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let response = try await session.respond(
                to: "Fix any grammar errors in this text. Only return the corrected text without any additional explanation:\n\n\(text)"
            )
            return response.content
        } catch {
            isProcessing = false
            throw FoundationModelsError.generationFailed
        }
        #else
        throw FoundationModelsError.unavailable
        #endif
    }

    func cleanupTranscript(_ text: String) async throws -> String {
        guard isAvailable else {
            logger.warning("cleanupTranscript skipped — FM unavailable")
            throw FoundationModelsError.unavailable
        }

        #if canImport(FoundationModels)
        ensureSession()
        guard let session else { throw FoundationModelsError.unavailable }

        isProcessing = true
        defer { isProcessing = false }

        logger.info("FM cleanup — input (\(text.count) chars): \"\(text)\"")

        do {
            let response = try await session.respond(
                to: """
                    Clean up this dictation transcript. Follow these rules strictly:
                    1. Delete ALL filler words and hesitation: um, uh, er, like, you know, sort of, kind of, I mean, basically, literally, well, so, right, actually, just, anyway, anyways
                    2. When the speaker says something and then corrects themselves (e.g., "The car is red. Oh, never mind. Actually it's blue. Wait, I mean green!"), OUTPUT ONLY THE FINAL CORRECTION: "The car is green." Delete the entire correction chain — every "actually", "never mind", "wait", "I mean" — and all content before the final statement.
                    3. Remove repeated words (e.g., "very very very good" → "very good")
                    4. Fix obvious speech-recognition errors using context (e.g., "dictive" → "dictate", "Swift Voice" → "SwiftDictate")
                    5. Preserve meaning and tone. ADD NOTHING new. OUTPUT ONLY the cleaned text, no commentary:\n\n\(text)
                    """
            )
            logger.info("FM cleanup — output (\(response.content.count) chars): \"\(response.content)\"")
            return response.content
        } catch let error as LanguageModelSession.GenerationError {
            logger.error("FM cleanup failed: \(String(describing: error))")
            switch error {
            case .exceededContextWindowSize:
                self.session = createNewSession()
                throw FoundationModelsError.contextWindowExceeded
            case .unsupportedLanguageOrLocale:
                throw FoundationModelsError.unsupportedLanguage
            case .assetsUnavailable:
                throw FoundationModelsError.unavailable
            case .guardrailViolation:
                throw FoundationModelsError.generationFailed
            case .unsupportedGuide:
                throw FoundationModelsError.generationFailed
            case .decodingFailure:
                throw FoundationModelsError.generationFailed
            case .rateLimited:
                throw FoundationModelsError.generationFailed
            case .concurrentRequests:
                throw FoundationModelsError.generationFailed
            case .refusal:
                throw FoundationModelsError.generationFailed
            @unknown default:
                throw FoundationModelsError.generationFailed
            }
        } catch {
            throw FoundationModelsError.modelError(error.localizedDescription)
        }
        #else
        throw FoundationModelsError.unavailable
        #endif
    }

    func invokeCustomPrompt(_ prompt: String, on text: String) async throws -> String {
        guard isAvailable else { throw FoundationModelsError.unavailable }

        #if canImport(FoundationModels)
        ensureSession()
        guard let session else { throw FoundationModelsError.unavailable }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let response = try await session.respond(to: "\(prompt)\n\nText: \(text)")
            return response.content
        } catch {
            isProcessing = false
            throw FoundationModelsError.generationFailed
        }
        #else
        throw FoundationModelsError.unavailable
        #endif
    }

    func resetSession() {
        #if canImport(FoundationModels)
        session = nil
        #endif
    }

    #if canImport(FoundationModels)
    private func ensureSession() {
        if session == nil {
            session = createNewSession()
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
