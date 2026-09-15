import SwiftUI

struct RecordingOverlayView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
                    .shadow(color: .red.opacity(0.6), radius: 4)

                Text("Recording")
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(formatDuration(at: context.date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Button(action: { appState.stopRecording() }) {
                    Image(systemName: "stop.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)

            Divider()

            if !appState.finalizedTranscript.isEmpty || !appState.volatileTranscript.isEmpty {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(appState.finalizedTranscript)
                                .font(.body)
                                .textSelection(.enabled)

                            if !appState.volatileTranscript.isEmpty {
                                Text(appState.volatileTranscript)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .id("volatile")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                    }
                    .task(id: appState.volatileTranscript) {
                        guard !appState.volatileTranscript.isEmpty else { return }
                        await Task.yield()
                        scrollProxy.scrollTo("volatile", anchor: .bottom)
                    }
                }
            } else {
                Text("Listening...")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(12)
            }
        }
        .frame(width: 320, height: 200, alignment: .top)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }

    private func formatDuration(at date: Date) -> String {
        let elapsed = max(0, date.timeIntervalSince(appState.recordingStartedAt ?? date))
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
