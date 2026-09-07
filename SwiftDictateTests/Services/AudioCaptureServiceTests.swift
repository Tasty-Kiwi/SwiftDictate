import AVFoundation
import AVFoundation
import Testing
@testable import SwiftDictate

struct AudioCaptureServiceTests {

    @Test func startFailureIsPropagatedWithoutLeavingTheServiceRunning() {
        let engine = TestCaptureEngine(startError: TestCaptureError.couldNotStart)
        let service = AudioCaptureService(captureEngine: engine)

        #expect(throws: TestCaptureError.couldNotStart) {
            _ = try service.start()
        }
        #expect(!service.isRunning)
        #expect(engine.startCount == 1)
    }

    @Test func stopFinishesTheActiveStreamAndStopsTheCaptureEngine() async throws {
        let engine = TestCaptureEngine()
        let service = AudioCaptureService(captureEngine: engine)
        let stream = try service.start()

        service.stop()

        var iterator = stream.makeAsyncIterator()
        let nextBuffer = await iterator.next()
        #expect(nextBuffer == nil)
        #expect(!service.isRunning)
        #expect(engine.stopCount == 1)
    }

    @Test func startRejectsASecondActiveCapture() throws {
        let engine = TestCaptureEngine()
        let service = AudioCaptureService(captureEngine: engine)
        _ = try service.start()

        #expect(throws: AudioCaptureError.alreadyRunning) {
            _ = try service.start()
        }
        #expect(engine.startCount == 1)

        service.stop()
    }

    @Test func capturedBufferOwnsACopyOfTapData() throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
        let source = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 2))
        source.frameLength = 2
        source.floatChannelData?[0][0] = 0.25
        source.floatChannelData?[0][1] = -0.5

        let captured = try #require(CapturedAudioBuffer(copying: source))
        source.floatChannelData?[0][0] = 1

        #expect(captured.buffer.frameLength == 2)
        #expect(captured.buffer.floatChannelData?[0][0] == 0.25)
        #expect(captured.buffer.floatChannelData?[0][1] == -0.5)
    }
}

private enum TestCaptureError: Error, Equatable {
    case couldNotStart
}

private final class TestCaptureEngine: AudioCapturingEngine {
    let startError: Error?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(startError: Error? = nil) {
        self.startError = startError
    }

    func startCapturing(_ handler: @escaping (CapturedAudioBuffer) -> Void) throws {
        startCount += 1
        if let startError {
            throw startError
        }
    }

    func stopCapturing() {
        stopCount += 1
    }
}
