import Foundation

enum RecordingState {
    case idle
    case requestingPermissions
    case ready
    case recording
    case processing
    case error(Error)

    var displayName: String {
        switch self {
        case .idle: "Idle"
        case .requestingPermissions: "Requesting Permissions..."
        case .ready: "Ready"
        case .recording: "Recording..."
        case .processing: "Processing..."
        case .error: "Error"
        }
    }

    var isRecording: Bool {
        if case .recording = self {
            return true
        }
        return false
    }

    var canStartRecording: Bool {
        switch self {
        case .ready, .idle:
            true
        default:
            false
        }
    }

    var isProcessing: Bool {
        if case .processing = self {
            return true
        }
        return false
    }

    var menuBarActivity: MenuBarActivity {
        switch self {
        case .recording: .recording
        case .processing: .processing
        default: .none
        }
    }
}

enum MenuBarActivity: Equatable {
    case none
    case recording
    case processing

    var microphoneSymbolName: String {
        switch self {
        case .none: "mic"
        case .recording, .processing: "mic.fill"
        }
    }
}
