import Foundation
import Observation

@MainActor
@Observable
final class TranscriptHistoryStore {
    private struct Archive: Codable {
        let schemaVersion: Int
        let entries: [TranscriptRecord]
    }

    private static let currentSchemaVersion = 1

    private(set) var entries: [TranscriptRecord] = []
    private(set) var persistenceWarning: String?

    private let fileURL: URL
    private let fileManager: FileManager
    private var persistenceIsBlocked = false

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        load()
    }

    @discardableResult
    func add(_ record: TranscriptRecord, retentionLimit: TranscriptRetentionLimit) -> Bool {
        guard !record.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        var updatedEntries = entries.filter { $0.id != record.id }
        updatedEntries.append(record)
        updatedEntries = Self.sortedAndPruned(updatedEntries, retentionLimit: retentionLimit)
        return persistAndPublish(updatedEntries)
    }

    @discardableResult
    func delete(id: TranscriptRecord.ID) -> Bool {
        let updatedEntries = entries.filter { $0.id != id }
        guard updatedEntries.count != entries.count else { return false }
        return persistAndPublish(updatedEntries)
    }

    @discardableResult
    func clear() -> Bool {
        guard !entries.isEmpty else { return true }
        return persistAndPublish([])
    }

    @discardableResult
    func applyRetentionLimit(_ retentionLimit: TranscriptRetentionLimit) -> Bool {
        let updatedEntries = Self.sortedAndPruned(entries, retentionLimit: retentionLimit)
        guard updatedEntries != entries else { return true }
        return persistAndPublish(updatedEntries)
    }

    func search(matching query: String) -> [TranscriptRecord] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return entries }
        return entries.filter {
            $0.text.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    func dismissWarning() {
        persistenceWarning = nil
    }

    private func load() {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let archive = try decoder.decode(Archive.self, from: data)
            guard archive.schemaVersion == Self.currentSchemaVersion else {
                throw TranscriptHistoryPersistenceError.unsupportedSchema(archive.schemaVersion)
            }
            entries = archive.entries.sorted { $0.completedAt > $1.completedAt }
        } catch {
            recoverFromCorruptArchive(error)
        }
    }

    private func recoverFromCorruptArchive(_ error: Error) {
        let backupURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("transcripts.corrupt-\(UUID().uuidString).json")

        do {
            try fileManager.moveItem(at: fileURL, to: backupURL)
            entries = []
            persistenceWarning = "Transcript history could not be read (\(error.localizedDescription)). The original file was preserved as \(backupURL.lastPathComponent)."
        } catch let backupError {
            persistenceIsBlocked = true
            entries = []
            persistenceWarning = "Transcript history could not be read or preserved. New history will not be saved until the file is repaired. \(backupError.localizedDescription)"
        }
    }

    private func persistAndPublish(_ updatedEntries: [TranscriptRecord]) -> Bool {
        guard !persistenceIsBlocked else { return false }

        do {
            let directoryURL = fileURL.deletingLastPathComponent()
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

            let archive = Archive(
                schemaVersion: Self.currentSchemaVersion,
                entries: updatedEntries
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(archive)
            try data.write(to: fileURL, options: .atomic)

            entries = updatedEntries
            persistenceWarning = nil
            return true
        } catch {
            persistenceWarning = "Transcript history could not be saved. \(error.localizedDescription)"
            return false
        }
    }

    private static func sortedAndPruned(
        _ entries: [TranscriptRecord],
        retentionLimit: TranscriptRetentionLimit
    ) -> [TranscriptRecord] {
        let sortedEntries = entries.sorted { $0.completedAt > $1.completedAt }
        guard let maximumEntryCount = retentionLimit.maximumEntryCount else {
            return sortedEntries
        }
        return Array(sortedEntries.prefix(maximumEntryCount))
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        let applicationIdentifier = Bundle.main.bundleIdentifier ?? "net.tastykiwi.SwiftDictate"
        return applicationSupportURL
            .appendingPathComponent(applicationIdentifier, isDirectory: true)
            .appendingPathComponent("transcripts.json")
    }
}

private enum TranscriptHistoryPersistenceError: LocalizedError {
    case unsupportedSchema(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            "Unsupported transcript history schema version \(version)."
        }
    }
}
