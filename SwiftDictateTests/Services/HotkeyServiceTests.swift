import Testing
@testable import SwiftDictate

struct HotkeyServiceTests {

    @Test func startsInNotMonitoringState() async {
        let service = HotkeyService()
        #expect(!service.isMonitoring)
    }

    @Test func startEnablesMonitoring() async throws {
        let service = HotkeyService()
        service.start()
        #expect(service.isMonitoring)
        service.stop()
    }

    @Test func stopDisablesMonitoring() async throws {
        let service = HotkeyService()
        service.start()
        #expect(service.isMonitoring)
        service.stop()
        #expect(!service.isMonitoring)
    }

    @Test func doubleStartDoesNotCreateDuplicateMonitors() async throws {
        let service = HotkeyService()
        service.start()
        service.start()
        #expect(service.isMonitoring)
        service.stop()
        #expect(!service.isMonitoring)
    }

    @Test func defaultConfiguration() {
        let service = HotkeyService()
        #expect(service.configuration.keyCode == 61)
    }

    @Test func updateConfigurationWhenMonitoring() async throws {
        let service = HotkeyService()
        service.start()
        #expect(service.isMonitoring)
        #expect(service.configuration.keyCode == 61)

        service.updateConfiguration(HotkeyConfiguration(keyCode: 54, modifiers: []))

        #expect(service.isMonitoring)
        #expect(service.configuration.keyCode == 54)

        service.stop()
    }

    @Test func updateConfigurationWhenStopped() {
        let service = HotkeyService()
        #expect(!service.isMonitoring)
        #expect(service.configuration.keyCode == 61)

        service.updateConfiguration(HotkeyConfiguration(keyCode: 54, modifiers: []))

        #expect(!service.isMonitoring)
        #expect(service.configuration.keyCode == 54)
    }

    @Test func stopWhenNotMonitoringIsNoop() {
        let service = HotkeyService()
        #expect(!service.isMonitoring)
        service.stop()
        #expect(!service.isMonitoring)
    }
}
