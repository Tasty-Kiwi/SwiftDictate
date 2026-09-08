import AVFoundation
import Testing
@testable import SwiftDictate

struct SpeechEngineServiceTests {

    @Test func startsWithoutAnInitializedInputStream() {
        let service = SpeechEngineService()

        #expect(!service.isReady)
        #expect(!service.isRunning)
        guard case .unknown = service.modelState else {
            Issue.record("A new service should not report a model state before setup.")
            return
        }
    }

    @Test func analysisCannotStartBeforeSetup() {
        let service = SpeechEngineService()

        #expect(throws: SpeechEngineError.inputStreamNotReady) {
            try service.startAnalysis()
        }
    }

    @Test func audioCannotBeFedBeforeSetup() {
        let service = SpeechEngineService()

        #expect(throws: SpeechEngineError.inputStreamNotReady) {
            try service.feedAudioBuffer(AVAudioPCMBuffer())
        }
    }

    @Test func regionalPreferenceExtensionResolvesToUnderlyingLanguageRegion() {
        let requested = Locale(identifier: "en-US-u-rg-ltzzzz")
        let supported = [Locale(identifier: "en-GB"), Locale(identifier: "en-US")]

        let resolved = SpeechEngineService.closestSupportedLocale(
            for: requested,
            from: supported
        )

        #expect(resolved?.identifier(.bcp47) == "en-US")
    }

    @Test func resetFinishesTheCurrentResultsStreamAndCreatesANewSessionStream() async {
        let service = SpeechEngineService()
        let firstStream = service.results()

        service.resetForNewSession()

        var firstIterator = firstStream.makeAsyncIterator()
        let firstResult = await firstIterator.next()
        #expect(firstResult == nil)

        let secondStream = service.results()
        let observation = ResultStreamObservation()
        let reader = Task {
            var iterator = secondStream.makeAsyncIterator()
            await observation.startedWaiting()
            _ = await iterator.next()
            await observation.completed()
        }

        await observation.waitUntilReaderIsWaiting()
        let completedBeforeReset = await observation.isCompleted
        #expect(!completedBeforeReset)

        service.resetForNewSession()
        await reader.value
        let completedAfterReset = await observation.isCompleted
        #expect(completedAfterReset)
    }
}

private actor ResultStreamObservation {
    private var isReaderWaiting = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private(set) var isCompleted = false

    func startedWaiting() {
        isReaderWaiting = true
        for waiter in waiters {
            waiter.resume()
        }
        waiters.removeAll()
    }

    func waitUntilReaderIsWaiting() async {
        guard !isReaderWaiting else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func completed() {
        isCompleted = true
    }
}
