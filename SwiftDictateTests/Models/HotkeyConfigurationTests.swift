import Testing
@testable import SwiftDictate

struct HotkeyConfigurationTests {

    @Test func displayNameUsesKnownKeyNamesAndModifierOrder() {
        let config = HotkeyConfiguration(keyCode: 55, modifiers: [.command, .shift])

        #expect(config.displayName == "Shift+Cmd+Left Command")
    }

    @Test func displayNameKeepsUnknownKeyCodesDiagnosable() {
        let config = HotkeyConfiguration(keyCode: 999, modifiers: [])

        #expect(config.displayName == "Key 999")
    }
}
