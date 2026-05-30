import Foundation
import CoreMedia

struct TranscriptionResult: Sendable {
    let text: String
    let attributedText: AttributedString
    let isFinal: Bool
    let audioTimeRange: CMTimeRange?
}
