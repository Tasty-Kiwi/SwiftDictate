import Foundation
import Testing

@testable import SwiftDictate

@MainActor
struct TranscriptHistoryStoreTests {
    @Test func recordsRoundTripNewestFirstAndCanBeDeletedOrCleared() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

        let older = makeRecord(text: "Older transcript", timestamp: 100)
        let newer = makeRecord(text: "Newer transcript", timestamp: 200)
        #expect(fixture.store.add(older, retentionLimit: .forever))
        #expect(fixture.store.add(newer, retentionLimit: .forever))
        #expect(fixture.store.entries.map(\.id) == [newer.id, older.id])

        let reloaded = TranscriptHistoryStore(fileURL: fixture.fileURL)
        #expect(reloaded.entries == [newer, older])

        #expect(reloaded.delete(id: newer.id))
        #expect(reloaded.entries == [older])
        #expect(reloaded.clear())
        #expect(reloaded.entries.isEmpty)
        #expect(TranscriptHistoryStore(fileURL: fixture.fileURL).entries.isEmpty)
    }

    @Test func searchIsCaseInsensitiveAndWhitespaceOnlyQueriesReturnEverything() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

        let first = makeRecord(text: "Ship the Axiomorix release", timestamp: 200)
        let second = makeRecord(text: "Review the design", timestamp: 100)
        fixture.store.add(first, retentionLimit: .forever)
        fixture.store.add(second, retentionLimit: .forever)

        #expect(fixture.store.search(matching: "AXIOMORIX") == [first])
        #expect(fixture.store.search(matching: "  ") == [first, second])
        #expect(fixture.store.search(matching: "missing").isEmpty)
    }

    @Test func retentionLimitsExposeExpectedCountsAndPruneImmediately() throws {
        #expect(TranscriptRetentionLimit.forever.maximumEntryCount == nil)
        #expect(TranscriptRetentionLimit.fifty.maximumEntryCount == 50)
        #expect(TranscriptRetentionLimit.oneHundred.maximumEntryCount == 100)
        #expect(TranscriptRetentionLimit.fiveHundred.maximumEntryCount == 500)
        #expect(TranscriptRetentionLimit.oneThousand.maximumEntryCount == 1_000)

        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

        for index in 0..<51 {
            fixture.store.add(
                makeRecord(text: "Transcript \(index)", timestamp: TimeInterval(index)),
                retentionLimit: .forever
            )
        }

        #expect(fixture.store.entries.count == 51)
        #expect(fixture.store.applyRetentionLimit(.fifty))
        #expect(fixture.store.entries.count == 50)
        #expect(fixture.store.entries.first?.text == "Transcript 50")
        #expect(fixture.store.entries.last?.text == "Transcript 1")
        #expect(TranscriptHistoryStore(fileURL: fixture.fileURL).entries.count == 50)
    }

    @Test func missingFileStartsEmptyAndCorruptFileIsPreserved() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

        #expect(fixture.store.entries.isEmpty)
        try Data("not json".utf8).write(to: fixture.fileURL)

        let recovered = TranscriptHistoryStore(fileURL: fixture.fileURL)
        #expect(recovered.entries.isEmpty)
        #expect(recovered.persistenceWarning != nil)
        #expect(!FileManager.default.fileExists(atPath: fixture.fileURL.path))

        let backups = try FileManager.default.contentsOfDirectory(
            at: fixture.directoryURL,
            includingPropertiesForKeys: nil
        )
        #expect(backups.contains { $0.lastPathComponent.hasPrefix("transcripts.corrupt-") })

        let replacement = makeRecord(text: "Recovered history", timestamp: 300)
        #expect(recovered.add(replacement, retentionLimit: .forever))
        #expect(TranscriptHistoryStore(fileURL: fixture.fileURL).entries == [replacement])
    }

    private func makeFixture() throws -> (
        store: TranscriptHistoryStore,
        directoryURL: URL,
        fileURL: URL
    ) {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TranscriptHistoryStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let fileURL = directoryURL.appendingPathComponent("transcripts.json")
        return (TranscriptHistoryStore(fileURL: fileURL), directoryURL, fileURL)
    }

    private func makeRecord(text: String, timestamp: TimeInterval) -> TranscriptRecord {
        TranscriptRecord(
            text: text,
            completedAt: Date(timeIntervalSince1970: timestamp),
            localeIdentifier: "en-GB",
            recordingDuration: 12.5
        )
    }
}
