import Testing
import Foundation
@testable import SwiftDictate

struct RecordingStateTests {

    @Test func initialStateIsIdle() {
        let state = RecordingState.idle
        #expect(state == .idle)
    }

    @Test func recordingStateIsRecording() {
        let state = RecordingState.recording
        #expect(state.isRecording)
    }

    @Test func idleIsNotRecording() {
        let state = RecordingState.idle
        #expect(!state.isRecording)
    }

    @Test func readyCanStartRecording() {
        let state = RecordingState.ready
        #expect(state.canStartRecording)
    }

    @Test func recordingCannotStartRecording() {
        let state = RecordingState.recording
        #expect(!state.canStartRecording)
    }

    @Test func processingIsProcessing() {
        let state = RecordingState.processing
        #expect(state.isProcessing)
    }

    @Test func idleIsNotProcessing() {
        let state = RecordingState.idle
        #expect(!state.isProcessing)
    }

    @Test func equalityWorks() {
        #expect(RecordingState.idle == RecordingState.idle)
        #expect(RecordingState.recording == RecordingState.recording)
        #expect(RecordingState.error(NSError(domain: "test", code: 1)) == RecordingState.error(NSError(domain: "test", code: 1)))
    }

    @Test func inequalityWorks() {
        #expect(RecordingState.idle != RecordingState.recording)
        #expect(RecordingState.ready != RecordingState.processing)
    }

    @Test func displayNamesAreNonEmpty() {
        for state in [RecordingState.idle, RecordingState.ready, RecordingState.recording, RecordingState.processing, RecordingState.paused] {
            #expect(!state.displayName.isEmpty)
        }
    }
}
