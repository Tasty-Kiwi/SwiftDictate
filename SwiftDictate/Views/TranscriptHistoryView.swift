import AppKit
import SwiftUI

struct TranscriptHistoryView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var selectedTranscriptID: TranscriptRecord.ID?
    @State private var isConfirmingClear = false

    var body: some View {
        VStack(spacing: 0) {
            if let warning = appState.transcriptHistoryStore.persistenceWarning {
                warningBanner(warning)
                Divider()
            }

            controls

            Divider()

            HSplitView {
                transcriptList
                    .frame(minWidth: 250, idealWidth: 290, maxWidth: 360)

                detail
                    .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear(perform: selectFirstVisibleTranscriptIfNeeded)
        .onChange(of: filteredEntries.map(\.id)) {
            selectFirstVisibleTranscriptIfNeeded()
        }
        .alert("Clear all transcripts?", isPresented: $isConfirmingClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear History", role: .destructive) {
                if appState.transcriptHistoryStore.clear() {
                    selectedTranscriptID = nil
                }
            }
        } message: {
            Text("This permanently deletes every saved transcript on this Mac.")
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Transcript History")
                    .font(.headline)
                Text(entryCountLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search transcripts", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 9)
            .frame(width: 220, height: 28)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 7))

            Picker("Keep", selection: transcriptHistoryLimitBinding) {
                ForEach(TranscriptRetentionLimit.allCases, id: \.self) { limit in
                    Text(limit.displayName).tag(limit)
                }
            }
            .labelsHidden()
            .frame(width: 145)
            .help("Transcript retention")

            Button(role: .destructive) {
                isConfirmingClear = true
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(appState.transcriptHistoryStore.entries.isEmpty)
            .help("Clear transcript history")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ViewBuilder
    private var transcriptList: some View {
        if appState.transcriptHistoryStore.entries.isEmpty {
            ContentUnavailableView(
                "No Transcripts",
                systemImage: "text.bubble",
                description: Text("Completed dictations will appear here.")
            )
        } else if filteredEntries.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            List(filteredEntries, selection: $selectedTranscriptID) { record in
                TranscriptHistoryRow(record: record)
                    .tag(record.id)
            }
            .listStyle(.sidebar)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let selectedTranscript {
            VStack(spacing: 0) {
                transcriptHeader(selectedTranscript)

                Divider()

                ScrollView {
                    Text(selectedTranscript.text)
                        .font(.system(.body, design: .rounded))
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(28)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.background)
                                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                        }
                        .padding(24)
                }
                .background(Color(nsColor: .underPageBackgroundColor))
            }
        } else {
            ContentUnavailableView(
                "Select a Transcript",
                systemImage: "doc.text.magnifyingglass",
                description: Text("Choose a saved dictation from the sidebar.")
            )
        }
    }

    private func transcriptHeader(_ record: TranscriptRecord) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.completedAt.formatted(date: .long, time: .shortened))
                    .font(.headline)
                Text("\(record.localeIdentifier)  ·  \(durationLabel(record.recordingDuration))  ·  \(record.text.count.formatted()) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            Button {
                copy(record.text)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Button(role: .destructive) {
                delete(record)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func warningBanner(_ warning: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(warning)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Dismiss") {
                appState.transcriptHistoryStore.dismissWarning()
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(.orange.opacity(0.08))
    }

    private var filteredEntries: [TranscriptRecord] {
        appState.transcriptHistoryStore.search(matching: searchText)
    }

    private var selectedTranscript: TranscriptRecord? {
        guard let selectedTranscriptID else { return nil }
        return appState.transcriptHistoryStore.entries.first { $0.id == selectedTranscriptID }
    }

    private var entryCountLabel: String {
        let count = appState.transcriptHistoryStore.entries.count
        return count == 1 ? "1 saved transcript" : "\(count) saved transcripts"
    }

    private var transcriptHistoryLimitBinding: Binding<TranscriptRetentionLimit> {
        Binding(
            get: { appState.settings.transcriptHistoryLimit },
            set: { appState.updateTranscriptHistoryLimit($0) }
        )
    }

    private func selectFirstVisibleTranscriptIfNeeded() {
        let visibleIDs = Set(filteredEntries.map(\.id))
        if let selectedTranscriptID, visibleIDs.contains(selectedTranscriptID) {
            return
        } else {
            selectedTranscriptID = filteredEntries.first?.id
        }
    }

    private func delete(_ record: TranscriptRecord) {
        guard appState.transcriptHistoryStore.delete(id: record.id) else { return }
        selectedTranscriptID = filteredEntries.first?.id
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func durationLabel(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration.rounded()))
        if seconds < 60 {
            return "\(seconds) sec"
        }
        return "\(seconds / 60) min \(seconds % 60) sec"
    }
}

private struct TranscriptHistoryRow: View {
    let record: TranscriptRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(record.completedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(record.text.replacingOccurrences(of: "\n", with: " "))
                .font(.body)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
