import Testing
@testable import SwiftDictate

struct HotkeyConfigurationTests {

    @Test func defaultConfiguration() {
        let config = HotkeyConfiguration.default
        #expect(config.keyCode == 61)
        #expect(config.modifiers == [])
    }

    @Test func requiresAccessibility() {
        let config = HotkeyConfiguration.default
        #expect(config.requiresAccessibility)
    }

    @Test func defaultDisplayNameIsNotEmpty() {
        let config = HotkeyConfiguration.default
        #expect(!config.displayName.isEmpty)
    }

    @Test func rightOptionDisplayName() {
        let config = HotkeyConfiguration(keyCode: 61, modifiers: [])
        #expect(config.displayName == "Right Option")
    }

    @Test func rightCommandDisplayName() {
        let config = HotkeyConfiguration(keyCode: 54, modifiers: [])
        #expect(config.displayName == "Right Command")
    }

    @Test func f5DisplayName() {
        let config = HotkeyConfiguration(keyCode: 96, modifiers: [])
        #expect(config.displayName == "F5")
    }

    @Test func modifierDisplayNameIncludesModifiers() {
        let config = HotkeyConfiguration(keyCode: 96, modifiers: .command)
        #expect(config.displayName.contains("Cmd"))
        #expect(config.displayName.contains("F5"))
    }

    @Test func combinationDisplayName() {
        let config = HotkeyConfiguration(keyCode: 55, modifiers: [.command, .shift])
        #expect(config.displayName.contains("Cmd"))
        #expect(config.displayName.contains("Shift"))
        #expect(config.displayName.contains("Left Command"))
    }

    @Test func unknownKeyCodeDisplayName() {
        let config = HotkeyConfiguration(keyCode: 999, modifiers: [])
        #expect(config.displayName.contains("Key"))
        #expect(config.displayName.contains("999"))
    }

    @Test func presetOptionsHaveValidKeys() {
        for (_, config) in HotkeyConfiguration.presetOptions {
            #expect(config.keyCode > 0)
        }
    }

    @Test func presetOptionsHaveDisplayNames() {
        for (name, config) in HotkeyConfiguration.presetOptions {
            #expect(!name.isEmpty)
            #expect(!config.displayName.isEmpty)
        }
    }
}
