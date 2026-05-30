import SwiftUI

struct PermissionsOnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var requestingPermission: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "mic.badge.ellipsis")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Welcome to SwiftDictate")
                .font(.title)

            Text("SwiftDictate needs a few permissions to work. Everything runs locally on your device — your data never leaves your Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 16) {
                permissionRow(
                    name: "Microphone",
                    icon: "mic.fill",
                    granted: appState.permissionsService.microphoneAuthorized,
                    description: "To capture your voice for transcription."
                )

                permissionRow(
                    name: "Accessibility",
                    icon: "accessibility",
                    granted: appState.permissionsService.accessibilityTrusted,
                    description: "To insert transcribed text into other apps."
                )
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

            Button(action: requestPermissions) {
                if requestingPermission {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Grant Permissions")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(requestingPermission)

            if appState.hasRequiredPermissions {
                Button("Start Using SwiftDictate") {
                    Task {
                        await appState.setupSpeechEngine()
                        appState.recordingState = appState.speechEngineService.isReady ? .ready : .error(SpeechEngineError.transcriberNotInitialized)
                        appState.onboardingWindow?.close()
                        appState.onboardingWindow = nil
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(40)
        .frame(width: 440)
        .onAppear {
            appState.permissionsService.refreshAll()
        }
    }

    private func permissionRow(name: String, icon: String, granted: Bool, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func requestPermissions() {
        requestingPermission = true
        Task {
            let micGranted = await appState.permissionsService.requestMicrophone()

            if !appState.permissionsService.accessibilityTrusted {
                appState.permissionsService.requestAccessibility()
                await appState.permissionsService.pollAccessibilityUntilTrusted()
            }

            if micGranted {
                _ = await appState.permissionsService.requestSpeechRecognition()
            }

            appState.permissionsService.refreshAll()
            requestingPermission = false

            if appState.hasRequiredPermissions {
                appState.recordingState = .ready
            }
        }
    }
}
