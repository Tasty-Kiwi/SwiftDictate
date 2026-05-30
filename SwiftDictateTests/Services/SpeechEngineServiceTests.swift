import Testing
import AVFoundation
import Foundation
@testable import SwiftDictate

struct SpeechEngineServiceTests {

    @Test func initialModelStateIsUnknown() {
        let service = SpeechEngineService()
        #expect(service.modelState == .unknown)
    }

    @Test func initiallyNotReady() {
        let service = SpeechEngineService()
        #expect(!service.isReady)
    }

    @Test func initiallyNotRunning() {
        let service = SpeechEngineService()
        #expect(!service.isRunning)
    }

    @Test func startAnalysisWhenNotReadyThrows() {
        let service = SpeechEngineService()
        #expect(!service.isReady)
        #expect(throws: SpeechEngineError.inputStreamNotReady) {
            try service.startAnalysis()
        }
    }

    @Test func feedAudioBufferWhenNotReadyThrows() {
        let service = SpeechEngineService()
        #expect(!service.isReady)
        #expect(throws: SpeechEngineError.inputStreamNotReady) {
            try service.feedAudioBuffer(AVAudioPCMBuffer())
        }
    }

    @Test func stopAnalysisWhenNotRunningIsNoop() {
        let service = SpeechEngineService()
        #expect(!service.isRunning)
        service.stopAnalysis()
        #expect(!service.isRunning)
    }

    @Test func cancelWhenIdleIsSafe() {
        let service = SpeechEngineService()
        service.cancel()
        #expect(!service.isReady)
        #expect(!service.isRunning)
    }

    @Test func resultsReturnsStream() {
        let service = SpeechEngineService()
        let stream = service.results()
        #expect(type(of: stream) == AsyncStream<TranscriptionResult>.self)
    }

    @Test func modelStateEquality() {
        #expect(SpeechEngineService.ModelState.unknown == SpeechEngineService.ModelState.unknown)
        #expect(SpeechEngineService.ModelState.ready == SpeechEngineService.ModelState.ready)
        #expect(SpeechEngineService.ModelState.notRegistered == SpeechEngineService.ModelState.notRegistered)
        #expect(SpeechEngineService.ModelState.downloading == SpeechEngineService.ModelState.downloading)
    }

    @Test func modelStateErrorEquality() {
        let errorA = NSError(domain: "test", code: 1)
        let errorB = NSError(domain: "test", code: 1)

        #expect(SpeechEngineService.ModelState.failed(errorA) == SpeechEngineService.ModelState.failed(errorB))
    }

    @Test func modelStateInequality() {
        #expect(SpeechEngineService.ModelState.unknown != SpeechEngineService.ModelState.ready)
        #expect(SpeechEngineService.ModelState.ready != SpeechEngineService.ModelState.notRegistered)
    }
}
