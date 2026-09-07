import AppKit
import Testing
@testable import SwiftDictate

struct HotkeyServiceTests {

    @Test func matchingKeyDownAndUpTriggerOnePressAndRelease() {
        let service = HotkeyService()
        var pressCount = 0
        var releaseCount = 0
        service.onHotkeyPressed = { pressCount += 1 }
        service.onHotkeyReleased = { releaseCount += 1 }

        service.process(event(.keyDown, keyCode: 61))
        service.process(event(.keyDown, keyCode: 61))
        service.process(event(.keyUp, keyCode: 61))
        service.process(event(.keyUp, keyCode: 61))

        #expect(pressCount == 1)
        #expect(releaseCount == 1)
        #expect(!service.isHotkeyPressed)
    }

    @Test func eventsWithWrongKeyOrModifiersAreIgnored() {
        let service = HotkeyService()
        service.configuration = HotkeyConfiguration(keyCode: 96, modifiers: .command)
        var pressCount = 0
        service.onHotkeyPressed = { pressCount += 1 }

        service.process(event(.keyDown, keyCode: 97, modifiers: .command))
        service.process(event(.keyDown, keyCode: 96))

        #expect(pressCount == 0)
        #expect(!service.isHotkeyPressed)
    }

    @Test func modifierHotkeyUsesFlagsChangedEvents() {
        let service = HotkeyService()
        var pressCount = 0
        var releaseCount = 0
        service.onHotkeyPressed = { pressCount += 1 }
        service.onHotkeyReleased = { releaseCount += 1 }

        service.process(event(.flagsChanged, keyCode: 61, modifiers: .option))
        service.process(event(.flagsChanged, keyCode: 61))

        #expect(pressCount == 1)
        #expect(releaseCount == 1)
        #expect(!service.isHotkeyPressed)
    }

    @Test func changingConfigurationWhileStoppedDoesNotStartMonitoring() {
        let service = HotkeyService()

        service.updateConfiguration(HotkeyConfiguration(keyCode: 54, modifiers: []))

        #expect(service.configuration.keyCode == 54)
        #expect(!service.isMonitoring)
    }

    private func event(
        _ kind: HotkeyEvent.Kind,
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags = []
    ) -> HotkeyEvent {
        HotkeyEvent(kind: kind, keyCode: keyCode, modifiers: modifiers)
    }
}
