import Testing
import Foundation
@testable import SwiftDictate

struct AppSettingsTests {

    @Test func defaultRecordingModeIsPushToTalk() {
        let settings = AppSettings()
        #expect(settings.recordingMode == .pushToTalk)
    }

    @Test func defaultEnableFoundationModelsIsTrue() {
        let settings = AppSettings()
        #expect(settings.enableFoundationModels)
    }

    @Test func defaultAutoInsertTextIsTrue() {
        let settings = AppSettings()
        #expect(settings.autoInsertText)
    }

    @Test func defaultEnablePunctuationRestorationIsTrue() {
        let settings = AppSettings()
        #expect(settings.enablePunctuationRestoration)
    }

    @Test func defaultEnableGrammarCorrectionIsTrue() {
        let settings = AppSettings()
        #expect(settings.enableGrammarCorrection)
    }

    @Test func settingRecordingModePersists() {
        let settings = AppSettings()

        settings.recordingMode = .toggle
        #expect(settings.recordingMode == .toggle)
        #expect(settings.recordingModeRaw == AppSettings.RecordingMode.toggle.rawValue)

        settings.recordingMode = .pushToTalk
        #expect(settings.recordingMode == .pushToTalk)
    }

    @Test func toggleSettingsPersist() {
        let settings = AppSettings()

        settings.enableFoundationModels = false
        #expect(!settings.enableFoundationModels)

        settings.enableFoundationModels = true
        #expect(settings.enableFoundationModels)

        settings.autoInsertText = false
        #expect(!settings.autoInsertText)

        settings.autoInsertText = true
        #expect(settings.autoInsertText)
    }

    @Test func preferredLocaleHasValidIdentifier() {
        let settings = AppSettings()
        let locale = settings.preferredLocale
        #expect(!locale.identifier(.bcp47).isEmpty)
    }

    @Test func recordingModesHaveDisplayNames() {
        for mode in AppSettings.RecordingMode.allCases {
            #expect(!mode.displayName.isEmpty)
            #expect(!mode.description.isEmpty)
        }
    }

    @Test func recordingModesAllCases() {
        let allModes = AppSettings.RecordingMode.allCases
        #expect(allModes.count == 2)
        #expect(allModes.contains(.pushToTalk))
        #expect(allModes.contains(.toggle))
    }

    @Test func userDefaultsPersistenceRoundtrip() {
        let defaults = UserDefaults.standard

        let settingsA = AppSettings()
        settingsA.enableFoundationModels = false
        settingsA.autoInsertText = false

        let settingsB = AppSettings()
        #expect(settingsB.enableFoundationModels == false)
        #expect(settingsB.autoInsertText == false)

        defaults.removeObject(forKey: "enableFoundationModels")
        defaults.removeObject(forKey: "autoInsertText")
    }
}
