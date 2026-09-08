import Testing
import Foundation
@testable import SwiftDictate

struct AppSettingsTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func defaultsAreAppliedToAnEmptyStore() {
        let settings = AppSettings(defaults: makeDefaults(), locale: Locale(identifier: "en-GB"))

        #expect(settings.recordingMode == .toggle)
        #expect(settings.enableFoundationModels)
        #expect(settings.enablePunctuationRestoration)
        #expect(settings.enableGrammarCorrection)
        #expect(settings.enableSmartCleanup)
        #expect(!settings.enableProgrammingDirectives)
        #expect(!settings.usePrivateCloudCompute)
        #expect(settings.intelligenceProviderPreference == .onDevice)
        #expect(settings.autoInsertText)
        #expect(settings.restoreClipboardAfterPaste)
        #expect(settings.preferredLocale.identifier(.bcp47) == "en-GB")
        #expect(settings.customWords.isEmpty)
    }

    @Test func recordingModeAndOptionsPersistInTheInjectedStore() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.recordingMode = .pushToTalk
        settings.enableFoundationModels = false
        settings.autoInsertText = false
        settings.enableProgrammingDirectives = true
        settings.usePrivateCloudCompute = true
        settings.preferredLocaleIdentifier = "lt-LT"
        #expect(settings.addCustomWord("  Axiomorix  "))
        #expect(settings.addCustomWord("Foundation Models"))

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.recordingMode == .pushToTalk)
        #expect(!reloaded.enableFoundationModels)
        #expect(!reloaded.autoInsertText)
        #expect(reloaded.enableProgrammingDirectives)
        #expect(reloaded.usePrivateCloudCompute)
        #expect(reloaded.intelligenceProviderPreference == .onDevice)
        #expect(reloaded.preferredLocale.identifier(.bcp47) == "lt-LT")
        #expect(reloaded.customWords == ["Axiomorix", "Foundation Models"])
    }

    @Test func privateCloudFeatureIsDisabledForStandardBuilds() {
        #expect(!FeatureFlags.privateCloudCompute)

        let settings = AppSettings(defaults: makeDefaults())
        settings.usePrivateCloudCompute = true
        #expect(settings.intelligenceProviderPreference == .onDevice)
    }

    @Test func processingOptionsAreCapturedFromCurrentSettings() {
        let settings = AppSettings(defaults: makeDefaults())
        settings.enableFoundationModels = true
        settings.enableSmartCleanup = false
        settings.enablePunctuationRestoration = true
        settings.enableGrammarCorrection = false
        settings.enableProgrammingDirectives = true
        #expect(settings.addCustomWord("Axiomorix"))

        #expect(
            settings.transcriptProcessingOptions == TranscriptProcessingOptions(
                foundationModelsEnabled: true,
                smartCleanupEnabled: false,
                punctuationRestorationEnabled: true,
                grammarCorrectionEnabled: false,
                programmingDirectivesEnabled: true,
                customWords: ["Axiomorix"]
            )
        )
    }

    @Test func invalidPersistedRecordingModeFallsBackToToggle() {
        let defaults = makeDefaults()
        defaults.set("unknown", forKey: "recordingMode")

        let settings = AppSettings(defaults: defaults)
        #expect(settings.recordingMode == .toggle)
    }

    @Test func customWordsAreNormalizedDeduplicatedAndRemovable() {
        let defaults = makeDefaults()
        defaults.set([" Axiomorix ", "axiomorix", "", "Foundation\nModels"], forKey: "customWords")
        let settings = AppSettings(defaults: defaults)

        #expect(settings.customWords == ["Axiomorix", "Foundation Models"])
        #expect(!settings.addCustomWord("AXIOMORIX"))
        #expect(!settings.addCustomWord("  \n "))

        settings.removeCustomWord("Axiomorix")
        #expect(settings.customWords == ["Foundation Models"])
        #expect(AppSettings(defaults: defaults).customWords == ["Foundation Models"])
    }
}
