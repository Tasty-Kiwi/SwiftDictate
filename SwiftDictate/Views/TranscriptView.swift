import SwiftUI

struct TranscriptView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Transcript")
                    .font(.headline)
                Spacer()

                if !appState.finalizedTranscript.isEmpty {
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(appState.finalizedTranscript, forType: .string)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)

                    Button("Clear") {
                        appState.resetTranscript()
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }

            ScrollView {
                if appState.finalizedTranscript.isEmpty && appState.volatileTranscript.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        if !appState.finalizedTranscript.isEmpty {
                            Text(appState.finalizedTranscript)
                                .font(.body)
                                .textSelection(.enabled)
                        }

                        if !appState.volatileTranscript.isEmpty {
                            Text(appState.volatileTranscript)
                                .font(.body)
                                .foregroundStyle(.secondary.opacity(0.6))
                                .textSelection(.enabled)
                                .id("volatile")
                        }
                    }
                }
            }
            .frame(minHeight: 100)
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("Your transcript will appear here")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
