import Testing
@testable import SwiftDictate

struct RecordingStateTests {
    @Test func menuBarActivityTracksOnlyRecordingAndProcessing() {
        #expect(RecordingState.idle.menuBarActivity == .none)
        #expect(RecordingState.requestingPermissions.menuBarActivity == .none)
        #expect(RecordingState.ready.menuBarActivity == .none)
        #expect(RecordingState.recording.menuBarActivity == .recording)
        #expect(RecordingState.processing.menuBarActivity == .processing)
        #expect(RecordingState.error(TestError()).menuBarActivity == .none)
    }

    @Test func menuBarActivityUsesAnOutlineAtIdleAndFilledColoredActiveStates() {
        #expect(MenuBarActivity.none.microphoneSymbolName == "mic")
        #expect(MenuBarActivity.recording.microphoneSymbolName == "mic.fill")
        #expect(MenuBarActivity.processing.microphoneSymbolName == "mic.fill")
        #expect(MenuBarActivity.recording.accessibilityDescription == "SwiftDictate recording")
        #expect(MenuBarActivity.processing.accessibilityDescription == "SwiftDictate processing")
        #expect(MenuBarActivity.none.tint == .primary)
        #expect(MenuBarActivity.recording.tint == .red)
        #expect(MenuBarActivity.processing.tint == .yellow)
    }
}

private struct TestError: Error {}
