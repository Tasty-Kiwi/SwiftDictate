import Foundation
import Testing

@testable import SwiftDictate

@MainActor
struct TranscriptArchivingTests {
    @Test func effectiveTranscriptIsArchivedOnceAndEmptyTextIsIgnored() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TranscriptArchivingTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let fileURL = directoryURL.appendingPathComponent("transcripts.json")
        let historyStore = TranscriptHistoryStore(fileURL: fileURL)

        let suiteName = "TranscriptArchivingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)
        settings.preferredLocaleIdentifier = "lt-LT"
        let appState = AppState(settings: settings, transcriptHistoryStore: historyStore)
        let completionDate = Date(timeIntervalSince1970: 1_000)

        #expect(!appState.archiveCompletedTranscript("  \n", duration: 2))
        #expect(
            appState.archiveCompletedTranscript(
                "Final processed text.",
                completedAt: completionDate,
                duration: 7.25
            )
        )
        #expect(
            !appState.archiveCompletedTranscript(
                "Duplicate for the same recording.",
                completedAt: completionDate,
                duration: 7.25
            )
        )

        let record = try #require(historyStore.entries.first)
        #expect(historyStore.entries.count == 1)
        #expect(record.text == "Final processed text.")
        #expect(record.completedAt == completionDate)
        #expect(record.localeIdentifier == "lt-LT")
        #expect(record.recordingDuration == 7.25)
    }
}
