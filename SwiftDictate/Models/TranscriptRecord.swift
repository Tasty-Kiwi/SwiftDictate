import Foundation

struct TranscriptRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let text: String
    let completedAt: Date
    let localeIdentifier: String
    let recordingDuration: TimeInterval

    init(
        id: UUID = UUID(),
        text: String,
        completedAt: Date = .now,
        localeIdentifier: String,
        recordingDuration: TimeInterval
    ) {
        self.id = id
        self.text = text
        self.completedAt = completedAt
        self.localeIdentifier = localeIdentifier
        self.recordingDuration = recordingDuration
    }
}

enum TranscriptRetentionLimit: Int, CaseIterable, Codable, Sendable {
    case forever = 0
    case fifty = 50
    case oneHundred = 100
    case fiveHundred = 500
    case oneThousand = 1_000

    var maximumEntryCount: Int? {
        self == .forever ? nil : rawValue
    }

    var displayName: String {
        switch self {
        case .forever: "Forever"
        case .fifty: "50 transcripts"
        case .oneHundred: "100 transcripts"
        case .fiveHundred: "500 transcripts"
        case .oneThousand: "1,000 transcripts"
        }
    }
}
