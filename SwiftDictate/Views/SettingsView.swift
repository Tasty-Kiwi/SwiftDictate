import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            recordingSettings
                .tabItem {
                    Label("Recording", systemImage: "mic.fill")
                }

            processingSettings
                .tabItem {
                    Label("Processing", systemImage: "brain")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 480, height: 340)
    }

    private var generalSettings: some View {
        Form {
            Section("Hotkey") {
                HStack {
                    Text("Record Hotkey")
                    Spacer()
                    Text(appState.hotkeyService.configuration.displayName)
                        .foregroundStyle(.secondary)
                }

                Text("Custom hotkey configuration will be available in a future update.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Permissions") {
                permissionRow("Microphone", granted: appState.permissionsService.microphoneAuthorized) {
                    Task { _ = await appState.permissionsService.requestMicrophone() }
                    appState.permissionsService.refreshAll()
                }

                permissionRow("Accessibility", granted: appState.permissionsService.accessibilityTrusted) {
                    appState.permissionsService.openAccessibilitySettings()
                }
            }
        }
        .formStyle(.grouped)
    }

    private var recordingSettings: some View {
        Form {
            Section("Recording Mode") {
                Picker("Mode", selection: recordingModeBinding) {
                    ForEach(AppSettings.RecordingMode.allCases, id: \.self) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.displayName)
                                .font(.body)
                            Text(mode.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
        }
        .formStyle(.grouped)
    }

    private var processingSettings: some View {
        Form {
            Section("Apple Intelligence") {
                Toggle("Enable Foundation Models", isOn: fmBinding)
                    .disabled(!fmAvailable)

                Toggle("Punctuation Restoration", isOn: punctuationBinding)
                    .disabled(!appState.settings.enableFoundationModels || !fmAvailable)

                Toggle("Grammar Correction", isOn: grammarBinding)
                    .disabled(!appState.settings.enableFoundationModels || !fmAvailable)

                Toggle("Smart Cleanup", isOn: smartCleanupBinding)
                    .disabled(!appState.settings.enableFoundationModels || !fmAvailable)

                if !fmAvailable {
                    Label(
                        "Apple Intelligence is not available on this device or is disabled in System Settings.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }

            Section("Text Insertion") {
                Toggle("Auto-insert text into focused app", isOn: autoInsertBinding)
                Toggle("Clear clipboard after paste", isOn: clearClipboardAfterPasteBinding)
                    .disabled(!appState.settings.autoInsertText)
            }
        }
        .formStyle(.grouped)
    }

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Image(systemName: "microphone.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("SwiftDictate")
                .font(.title)

            Text("Fully on-device dictation for macOS 26+")
                .foregroundStyle(.secondary)

            Text("Version 1.0")
                .font(.caption)
                .foregroundStyle(.tertiary)

            VStack(spacing: 4) {
                Text("Powered by Apple SpeechAnalyzer")
                Text("and Foundation Models")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)

            Divider()
                .frame(width: 200)

            HStack {
                Spacer()
                Text("All processing is performed locally on your device. No data is ever transmitted off-device.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
        }
        .padding(40)
    }

    private var fmAvailable: Bool {
        appState.foundationModelsService.isAvailable
    }

    private var fmBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.enableFoundationModels },
            set: { appState.settings.enableFoundationModels = $0 }
        )
    }

    private var punctuationBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.enablePunctuationRestoration },
            set: { appState.settings.enablePunctuationRestoration = $0 }
        )
    }

    private var grammarBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.enableGrammarCorrection },
            set: { appState.settings.enableGrammarCorrection = $0 }
        )
    }

    private var smartCleanupBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.enableSmartCleanup },
            set: { appState.settings.enableSmartCleanup = $0 }
        )
    }

    private var autoInsertBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.autoInsertText },
            set: { appState.settings.autoInsertText = $0 }
        )
    }

    private var clearClipboardAfterPasteBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.clearClipboardAfterPaste },
            set: { appState.settings.clearClipboardAfterPaste = $0 }
        )
    }

    private var recordingModeBinding: Binding<AppSettings.RecordingMode> {
        Binding(
            get: { appState.settings.recordingMode },
            set: { appState.settings.recordingMode = $0 }
        )
    }

    private func permissionRow(
        _ name: String,
        granted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(granted ? .green : .red)

            Text(name)

            Spacer()

            if !granted {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
}
