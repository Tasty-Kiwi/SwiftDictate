import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var newCustomWord = ""
    @State private var selectedTab = SettingsTab.general

    var body: some View {
        VStack(spacing: 0) {
            settingsToolbar

            Divider()

            ZStack {
                tabPage(generalSettings, for: .general)
                tabPage(recordingSettings, for: .recording)
                tabPage(processingSettings, for: .processing)
                tabPage(dictionarySettings, for: .dictionary)
                tabPage(aboutTab, for: .about)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 500, height: 450)
    }

    private var settingsToolbar: some View {
        HStack(spacing: 2) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 27, weight: .regular))
                            .frame(height: 30)

                        Text(tab.title)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                    .frame(width: 88, height: 68)
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.10))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                                }
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(tab.title)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func tabPage<Content: View>(_ content: Content, for tab: SettingsTab) -> some View {
        content
            .opacity(selectedTab == tab ? 1 : 0)
            .allowsHitTesting(selectedTab == tab)
            .accessibilityHidden(selectedTab != tab)
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
            }

            Section("Permissions") {
                permissionRow("Microphone", granted: appState.permissionsService.microphoneAuthorized) {
                    Task {
                        _ = await appState.permissionsService.requestMicrophone()
                        await appState.refreshPermissionsAndUpdateState()
                    }
                }

                permissionRow("Accessibility", granted: appState.permissionsService.accessibilityTrusted) {
                    appState.permissionsService.openAccessibilitySettings()
                }

                permissionRow("Speech Recognition", granted: appState.permissionsService.speechRecognitionAuthorized) {
                    Task {
                        _ = await appState.permissionsService.requestSpeechRecognition()
                        await appState.refreshPermissionsAndUpdateState()
                    }
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

                Toggle("Programming Directives", isOn: programmingDirectivesBinding)
                    .disabled(!appState.settings.enableFoundationModels || !fmAvailable)

                if appState.settings.enableProgrammingDirectives {
                    Text("Say “camel case user account” for userAccount or “snake case user account” for user_account.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !fmAvailable {
                    Label(
                        "Apple Intelligence is not available on this device or is disabled in System Settings.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }

            if FeatureFlags.privateCloudCompute {
                Section("Private Cloud Compute") {
                    Toggle(
                        "Use Private Cloud Compute when available",
                        isOn: privateCloudComputeBinding
                    )
                    .disabled(!appState.foundationModelsService.privateCloudStatus.isAvailable)

                    Text(appState.foundationModelsService.privateCloudStatus.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Requires an internet connection. If Apple’s service, quota, or network is unavailable, processing automatically retries on this Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Text Insertion") {
                Toggle("Auto-insert text into focused app", isOn: autoInsertBinding)
                Toggle("Restore previous clipboard after paste", isOn: restoreClipboardAfterPasteBinding)
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

            Text("Speech-to-text dictation for macOS 26+")
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

        }
        .padding(40)
    }

    private var dictionarySettings: some View {
        Form {
            Section {
                HStack {
                    TextField("Word or phrase", text: $newCustomWord)
                        .onSubmit(addCustomWord)

                    Button(action: addCustomWord) {
                        Label("Add", systemImage: "plus")
                    }
                    .disabled(normalizedNewCustomWord.isEmpty || customWordAlreadyExists)
                }
            } header: {
                Text("Custom Words")
            } footer: {
                Text("When Apple Intelligence is enabled, likely speech-recognition matches are corrected to these exact spellings.")
            }

            if appState.settings.customWords.isEmpty {
                ContentUnavailableView(
                    "No Custom Words",
                    systemImage: "text.book.closed",
                    description: Text("Add names, product terms, or phrases that need exact spelling.")
                )
            } else {
                Section("Dictionary") {
                    ForEach(appState.settings.customWords, id: \.self) { word in
                        HStack {
                            Text(word)
                            Spacer()
                            Button(role: .destructive) {
                                appState.settings.removeCustomWord(word)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove \(word)")
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var normalizedNewCustomWord: String {
        newCustomWord
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var customWordAlreadyExists: Bool {
        appState.settings.customWords.contains {
            $0.caseInsensitiveCompare(normalizedNewCustomWord) == .orderedSame
        }
    }

    private func addCustomWord() {
        guard appState.settings.addCustomWord(newCustomWord) else { return }
        newCustomWord = ""
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

    private var programmingDirectivesBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.enableProgrammingDirectives },
            set: { appState.settings.enableProgrammingDirectives = $0 }
        )
    }

    private var privateCloudComputeBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.usePrivateCloudCompute },
            set: { appState.settings.usePrivateCloudCompute = $0 }
        )
    }

    private var autoInsertBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.autoInsertText },
            set: { appState.settings.autoInsertText = $0 }
        )
    }

    private var restoreClipboardAfterPasteBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.restoreClipboardAfterPaste },
            set: { appState.settings.restoreClipboardAfterPaste = $0 }
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

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case recording
    case processing
    case dictionary
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .recording: "Recording"
        case .processing: "Processing"
        case .dictionary: "Dictionary"
        case .about: "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .recording: "mic"
        case .processing: "brain"
        case .dictionary: "text.book.closed"
        case .about: "info.circle"
        }
    }
}
