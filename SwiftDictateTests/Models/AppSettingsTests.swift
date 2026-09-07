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
        #expect(settings.autoInsertText)
        #expect(settings.restoreClipboardAfterPaste)
        #expect(settings.preferredLocale.identifier(.bcp47) == "en-GB")
    }

    @Test func recordingModeAndOptionsPersistInTheInjectedStore() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.recordingMode = .pushToTalk
        settings.enableFoundationModels = false
        settings.autoInsertText = false
        settings.preferredLocaleIdentifier = "lt-LT"

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.recordingMode == .pushToTalk)
        #expect(!reloaded.enableFoundationModels)
        #expect(!reloaded.autoInsertText)
        #expect(reloaded.preferredLocale.identifier(.bcp47) == "lt-LT")
    }

    @Test func invalidPersistedRecordingModeFallsBackToToggle() {
        let defaults = makeDefaults()
        defaults.set("unknown", forKey: "recordingMode")

        let settings = AppSettings(defaults: defaults)
        #expect(settings.recordingMode == .toggle)
    }
}
