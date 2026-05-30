import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !appState.hasRequiredPermissions {
                permissionsWarningSection

                Divider()
            }

            statusSection

            if appState.isRecording {
                Divider()
                transcriptSection
            }

            Divider()

            recordingModeSection

            Divider()

            actionButtons
        }
        .padding()
        .frame(minWidth: 280)
    }

    private var permissionsWarningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Permissions Required", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text("SwiftDictate needs microphone and accessibility permissions to function.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Open System Settings") {
                appState.permissionsService.openAccessibilitySettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(8)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(appState.recordingState.displayName)
                    .font(.headline)

                Spacer()

                if appState.isRecording {
                    PulseIndicator()
                } else if appState.isProcessing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if case .error(let error) = appState.recordingState {
                VStack(alignment: .leading, spacing: 6) {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Retry Setup") {
                        Task { await appState.retrySetup() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
    }

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Live Transcript")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(charCountDisplay)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !appState.finalizedTranscript.isEmpty {
                            Text(appState.finalizedTranscript)
                                .font(.body)
                        }

                        if !appState.volatileTranscript.isEmpty {
                            Text(appState.volatileTranscript)
                                .font(.body)
                                .foregroundStyle(.secondary.opacity(0.6))
                                .id("volatileEnd")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
                .onChange(of: appState.volatileTranscript) {
                    withAnimation {
                        proxy.scrollTo("volatileEnd", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var recordingModeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recording Mode")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Mode", selection: recordingModeBinding) {
                ForEach(AppSettings.RecordingMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var actionButtons: some View {
        HStack {
            if appState.canStartRecording {
                recordButton
            } else if appState.isRecording {
                stopButton
            }

            if !appState.finalizedTranscript.isEmpty {
                copyButton
            }

            Spacer()

            if appState.foundationModelsService.isAvailable {
                settingsButton
            }
        }
    }

    private var recordButton: some View {
        Button(action: { Task { await appState.toggleRecording() } }) {
            Label("Record", systemImage: "mic.fill")
        }
        .keyboardShortcut("r")
        .disabled(!appState.hasRequiredPermissions)
    }

    private var stopButton: some View {
        Button(action: { appState.stopRecording() }) {
            Label("Stop", systemImage: "stop.fill")
        }
        .keyboardShortcut(".")
    }

    private var copyButton: some View {
        Button(action: copyTranscript) {
            Label("Copy", systemImage: "doc.on.doc")
        }
        .labelStyle(.iconOnly)
        .help("Copy transcript to clipboard")
    }

    private var settingsButton: some View {
        Button(action: { openSettings() }) {
            Label("Settings", systemImage: "gearshape")
        }
        .labelStyle(.iconOnly)
        .help("Open Settings")
    }

    private var statusColor: Color {
        switch appState.recordingState {
        case .idle: .gray
        case .requestingPermissions: .yellow
        case .ready: .green
        case .recording: .red
        case .processing: .orange
        case .paused: .yellow
        case .error: .red
        }
    }

    private var charCountDisplay: String {
        let total = appState.finalizedTranscript.count + appState.volatileTranscript.count
        if total >= 1000 {
            return "\(total / 1000).\((total % 1000) / 100)k"
        }
        return "\(total)"
    }

    private var recordingModeBinding: Binding<AppSettings.RecordingMode> {
        Binding(
            get: { appState.settings.recordingMode },
            set: { appState.settings.recordingMode = $0 }
        )
    }

    private func copyTranscript() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(appState.finalizedTranscript, forType: .string)
    }

    private func openSettings() {
        Task { @MainActor in
            let settingsVC = NSHostingController(
                rootView: SettingsView().environment(appState)
            )

            let window = NSWindow(contentViewController: settingsVC)
            window.title = "SwiftDictate Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 480, height: 380))
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }
}

struct PulseIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        Image(systemName: "waveform")
            .font(.caption)
            .foregroundStyle(.red)
            .scaleEffect(isAnimating ? 1.2 : 0.8)
            .opacity(isAnimating ? 1.0 : 0.5)
            .animation(
                .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}
