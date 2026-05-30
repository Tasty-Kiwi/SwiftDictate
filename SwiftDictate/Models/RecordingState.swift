import Foundation

enum RecordingState: Equatable {
    case idle
    case requestingPermissions
    case ready
    case recording
    case processing
    case paused
    case error(Error)

    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.requestingPermissions, .requestingPermissions),
             (.ready, .ready),
             (.recording, .recording),
             (.processing, .processing),
             (.paused, .paused):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .idle: "Idle"
        case .requestingPermissions: "Requesting Permissions..."
        case .ready: "Ready"
        case .recording: "Recording..."
        case .processing: "Processing..."
        case .paused: "Paused"
        case .error: "Error"
        }
    }

    var isRecording: Bool {
        self == .recording
    }

    var canStartRecording: Bool {
        self == .ready || self == .idle
    }

    var isProcessing: Bool {
        self == .processing
    }
}
