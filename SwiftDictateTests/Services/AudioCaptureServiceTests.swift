import Testing
@testable import SwiftDictate

struct AudioCaptureServiceTests {

    @Test func initiallyNotRunning() {
        let service = AudioCaptureService()
        #expect(!service.isRunning)
    }

    @Test func formatIsAvailable() {
        let service = AudioCaptureService()
        #expect(service.format != nil)
    }

    @Test func stopWhenNotRunningDoesNotThrow() {
        let service = AudioCaptureService()
        service.stop()
        #expect(!service.isRunning)
    }
}
