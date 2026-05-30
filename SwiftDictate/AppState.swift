import SwiftUI
import AVFoundation
import Observation

@MainActor
@Observable
final class AppState {
    var recordingState: RecordingState = .idle
    var volatileTranscript: String = ""
    var finalizedTranscript: String = ""
    var currentTranscript: AttributedString = ""
    var errorMessage: String?
    var isRestoringState = false
    var showSettings = false
    var isProcessing = false
    var onboardingWindow: NSWindow?

    let permissionsService = PermissionsService()
    let audioCaptureService = AudioCaptureService()
    let speechEngineService = SpeechEngineService()
    let foundationModelsService = FoundationModelsService()
    let textInsertionService = TextInsertionService()
    let hotkeyService = HotkeyService()
    let settings = AppSettings()

    private var recordingTask: Task<Void, Never>?
    private var resultCollectionTask: Task<Void, Never>?
    private var audioStream: AsyncStream<AVAudioPCMBuffer>?
    private var hotkeyPressTask: Task<Void, Never>?
    private var hotkeyReleaseTask: Task<Void, Never>?
    private var workspaceObserver: (any NSObjectProtocol)?
    private var permissionPollTask: Task<Void, Never>?
    private var setupTask: Task<Void, Never>?

    deinit {
        MainActor.assumeIsolated {
            if let observer = workspaceObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(observer)
            }
        }
    }

    var isRecording: Bool { recordingState.isRecording }
    var canStartRecording: Bool { recordingState.canStartRecording }

    var hasRequiredPermissions: Bool {
        permissionsService.microphoneAuthorized && permissionsService.accessibilityTrusted
    }

    func initialize() async {
        permissionsService.refreshAll()
        foundationModelsService.checkAvailability()

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.permissionsService.refreshAll()
                if self?.hasRequiredPermissions == true,
                   self?.recordingState == .requestingPermissions {
                    self?.recordingState = .ready
                }
            }
        }

        if !hasRequiredPermissions {
            recordingState = .requestingPermissions
            startPermissionPolling()
        } else {
            recordingState = .ready
            await setupSpeechEngine()
        }

        setupHotkeyCallbacks()
    }

    private func startPermissionPolling() {
        permissionPollTask?.cancel()
        permissionPollTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { break }
                self.permissionsService.refreshAll()
                if self.hasRequiredPermissions, self.recordingState == .requestingPermissions {
                    self.recordingState = .ready
                    Task { await self.setupSpeechEngine() }
                    self.permissionPollTask?.cancel()
                }
            }
        }
    }

    private func setupHotkeyCallbacks() {
        hotkeyService.onHotkeyPressed = { [weak self] in
            self?.hotkeyPressTask = Task { @MainActor [weak self] in
                await self?.handleHotkeyPress()
            }
        }

        hotkeyService.onHotkeyReleased = { [weak self] in
            self?.hotkeyReleaseTask = Task { @MainActor [weak self] in
                await self?.handleHotkeyRelease()
            }
        }
    }

    private func handleHotkeyPress() async {
        switch settings.recordingMode {
        case .pushToTalk:
            if canStartRecording {
                await startRecording()
            }

        case .toggle:
            await toggleRecording()
        }
    }

    private func handleHotkeyRelease() async {
        if settings.recordingMode == .pushToTalk, isRecording {
            stopRecording()
        }
    }

    func setupSpeechEngine() async {
        guard !speechEngineService.isReady else { return }

        if let existing = setupTask {
            await existing.value
            return
        }

        setupTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.setupTask = nil }

            do {
                try await self.speechEngineService.setupTranscriber(locale: self.settings.preferredLocale)
            } catch {
                do {
                    try await self.speechEngineService.downloadModelIfNeeded(for: self.settings.preferredLocale)
                    try await self.speechEngineService.setupTranscriber(locale: self.settings.preferredLocale)
                } catch {
                    self.recordingState = .error(error)
                }
            }
        }

        await setupTask?.value
    }

    func startRecording() async {
        guard !isRecording else { return }

        if !hasRequiredPermissions {
            permissionsService.refreshAll()
            recordingState = .requestingPermissions
            return
        }

        if !speechEngineService.isReady {
            await setupSpeechEngine()
            guard speechEngineService.isReady else {
                handleError(SpeechEngineError.transcriberNotInitialized)
                return
            }
        }

        recordingState = .recording
        resetTranscript()
        errorMessage = nil

        do {
            audioStream = try audioCaptureService.start()

            try speechEngineService.startAnalysis()

            startResultCollection()

            guard let audioStream else {
                handleError(SpeechEngineError.inputStreamNotReady)
                return
            }

            recordingTask = Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    for await buffer in audioStream {
                        guard self.isRecording, !Task.isCancelled else { break }
                        try self.speechEngineService.feedAudioBuffer(buffer)
                    }
                } catch {
                    await MainActor.run {
                        self.handleError(error)
                    }
                }
            }
        } catch {
            handleError(error)
        }
    }

    private func startResultCollection() {
        resultCollectionTask = Task { @MainActor [weak self] in
            guard let self else { return }

            for await result in speechEngineService.results() {
                guard !Task.isCancelled else { break }

                await MainActor.run {
                    if result.isFinal {
                        self.finalizedTranscript += result.text
                        self.volatileTranscript = ""

                        if self.settings.autoInsertText {
                            Task {
                                try? await self.textInsertionService.insertText(
                                    result.text,
                                    autoInsert: self.settings.autoInsertText
                                )
                            }
                        }
                    } else {
                        self.volatileTranscript = result.text
                    }
                }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        recordingState = .processing

        audioCaptureService.stop()
        audioStream = nil

        recordingTask?.cancel()
        recordingTask = nil

        speechEngineService.finishInput()

        Task {
            do {
                try await speechEngineService.finalizeResults()
            } catch {
                handleError(error)
            }

            speechEngineService.resetForNewSession()
            resultCollectionTask?.cancel()
            resultCollectionTask = nil

            await setupSpeechEngine()

            recordingState = speechEngineService.isReady ? .ready : .error(SpeechEngineError.transcriberNotInitialized)
        }

        if settings.enableFoundationModels, !finalizedTranscript.isEmpty {
            processTranscript(finalizedTranscript)
        }
    }

    func toggleRecording() async {
        if isRecording {
            stopRecording()
        } else {
            await startRecording()
        }
    }

    func processTranscript(_ text: String) {
        guard settings.enableFoundationModels, foundationModelsService.isAvailable else {
            print("[SwiftDictate] FM processing skipped — enabled:\(settings.enableFoundationModels) available:\(foundationModelsService.isAvailable)")
            return
        }

        Task {
            do {
                var processed = text

                if settings.enableSmartCleanup {
                    print("[SwiftDictate] FM: starting smart cleanup...")
                    processed = try await foundationModelsService.cleanupTranscript(processed)
                    print("[SwiftDictate] FM: cleanup complete — \(processed.count) chars")
                }

                if settings.enablePunctuationRestoration {
                    print("[SwiftDictate] FM: starting punctuation restoration...")
                    processed = try await foundationModelsService.restorePunctuation(processed)
                }

                if settings.enableGrammarCorrection {
                    print("[SwiftDictate] FM: starting grammar correction...")
                    processed = try await foundationModelsService.correctGrammar(processed)
                }

                finalizedTranscript = processed
                print("[SwiftDictate] FM: all processing complete — final: \"\(processed)\"")
            } catch {
                print("[SwiftDictate] FM processing failed: \(error.localizedDescription)")
            }
        }
    }

    func resetTranscript() {
        volatileTranscript = ""
        finalizedTranscript = ""
        currentTranscript = ""
    }

    func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        recordingState = .error(error)

        if audioCaptureService.isRunning {
            audioCaptureService.stop()
        }

        if speechEngineService.isRunning {
            speechEngineService.stopAnalysis()
        }
    }

    func retrySetup() async {
        recordingState = .ready
        errorMessage = nil
        await setupSpeechEngine()
    }

    func cleanup() {
        stopRecording()
        hotkeyService.stop()
        speechEngineService.cancel()
        foundationModelsService.resetSession()
    }
}
