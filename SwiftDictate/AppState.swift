import SwiftUI
import AVFoundation
import Observation

@MainActor
@Observable
final class AppState {
    var recordingState: RecordingState = .idle
    var volatileTranscript: String = ""
    var finalizedTranscript: String = ""
    var recordingTriggeredByHotkey = false
    var recordingStartedAt: Date?

    let permissionsService = PermissionsService()
    let audioCaptureService = AudioCaptureService()
    let speechEngineService = SpeechEngineService()
    let foundationModelsService = FoundationModelsService()
    let textInsertionService = TextInsertionService()
    let hotkeyService = HotkeyService()
    let settings = AppSettings()
    private let windowController = AppWindowController()

    private var recordingTask: Task<Void, Never>?
    private var resultCollectionTask: Task<Void, Never>?
    private var audioStream: AsyncStream<CapturedAudioBuffer>?
    private var workspaceObserver: (any NSObjectProtocol)?
    private var setupTask: Task<Void, Never>?
    private var insertionTargetApplication: NSRunningApplication?
    private var recordingSessionID = UUID()
    private var hasCapturedAudio = false

    init() {
        Task {
            await initialize()
        }
    }

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
        permissionsService.allGranted
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
                guard let self else { return }
                await self.refreshPermissionsAndUpdateState()
            }
        }

        setupHotkeyCallbacks()

        if !hasRequiredPermissions {
            recordingState = .requestingPermissions
            showOnboarding()
        } else {
            startHotkeyMonitoringIfPossible()
            await setupSpeechEngine()
            if speechEngineService.isReady {
                recordingState = .ready
            }
        }
    }

    /// Requests the three permissions SwiftDictate needs without blocking startup
    /// while the user responds to the Accessibility system prompt.
    func requestRequiredPermissions() async {
        await permissionsService.requestRequiredPermissions()
        await refreshPermissionsAndUpdateState()
    }

    /// Refreshes permission state after the app becomes active again from System Settings.
    func refreshPermissionsAndUpdateState() async {
        permissionsService.refreshAll()

        guard hasRequiredPermissions else {
            if !isRecording && !recordingState.isProcessing {
                recordingState = .requestingPermissions
            }
            showOnboarding()
            return
        }

        startHotkeyMonitoringIfPossible()
        dismissOnboarding()

        if case .requestingPermissions = recordingState {
            await setupSpeechEngine()
            if speechEngineService.isReady {
                recordingState = .ready
            }
        }
    }

    private func startHotkeyMonitoringIfPossible() {
        guard permissionsService.accessibilityTrusted, !hotkeyService.isMonitoring else { return }
        hotkeyService.start()
    }

    private func setupHotkeyCallbacks() {
        hotkeyService.onHotkeyPressed = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handleHotkeyPress()
            }
        }

        hotkeyService.onHotkeyReleased = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handleHotkeyRelease()
            }
        }
    }

    private func handleHotkeyPress() async {
        switch settings.recordingMode {
        case .pushToTalk:
            guard canStartRecording else { return }
            recordingTriggeredByHotkey = true
            await startRecording()

            // A modifier-key tap can be released while speech setup or audio
            // startup is still suspended. Preserve that release instead of
            // leaving the newly started recording running indefinitely.
            if !hotkeyService.isHotkeyPressed, isRecording {
                stopRecording()
            }

        case .toggle:
            recordingTriggeredByHotkey = true
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
                try await self.speechEngineService.downloadModelIfNeeded(
                    for: self.settings.preferredLocale
                )
                try await self.speechEngineService.setupTranscriber(locale: self.settings.preferredLocale)
            } catch {
                self.recordingState = .error(error)
            }
        }

        await setupTask?.value
    }

    func startRecording() async {
        guard !isRecording else { return }

        if !hasRequiredPermissions {
            await refreshPermissionsAndUpdateState()
            return
        }

        if !speechEngineService.isReady {
            await setupSpeechEngine()
            guard speechEngineService.isReady else { return }
        }

        resetTranscript()
        recordingSessionID = UUID()
        hasCapturedAudio = false
        insertionTargetApplication = NSWorkspace.shared.frontmostApplication

        do {
            audioStream = try audioCaptureService.start()
            try speechEngineService.startAnalysis()
            startResultCollection()

            guard let audioStream else {
                handleError(SpeechEngineError.inputStreamNotReady)
                return
            }

            recordingState = .recording
            recordingStartedAt = .now

            if recordingTriggeredByHotkey {
                showOverlay()
            }

            recordingTask = Task { [weak self] in
                guard let self else { return }
                do {
                    for await capturedBuffer in audioStream {
                        guard self.isRecording, !Task.isCancelled else { break }
                        try self.speechEngineService.feedAudioBuffer(capturedBuffer.buffer)
                        self.hasCapturedAudio = true
                    }
                } catch {
                    self.handleError(error)
                }
            }
        } catch {
            handleError(error)
        }
    }

    private func startResultCollection() {
        resultCollectionTask = Task { [weak self] in
            guard let self else { return }

            for await result in speechEngineService.results() {
                guard !Task.isCancelled else { break }

                if result.isFinal {
                    self.finalizedTranscript += result.text
                    self.volatileTranscript = ""
                } else {
                    self.volatileTranscript = result.text
                }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        let sessionID = recordingSessionID
        let shouldFinalizeResults = hasCapturedAudio
        let processingOptions = settings.transcriptProcessingOptions
        let providerPreference = settings.intelligenceProviderPreference

        recordingState = .processing
        recordingStartedAt = nil
        dismissOverlay()
        recordingTriggeredByHotkey = false

        audioCaptureService.stop()
        audioStream = nil

        recordingTask?.cancel()
        recordingTask = nil

        speechEngineService.finishInput()

        // Very short modifier-key taps can end before AVAudioEngine produces
        // its first buffer. SpeechAnalyzer may then wait forever for input that
        // never existed, so reset that empty session without finalizing it.
        guard shouldFinalizeResults else {
            Task { await prepareForNextRecording() }
            return
        }

        Task {
            do {
                try await speechEngineService.finalizeResults()
            } catch {
                guard recordingSessionID == sessionID else { return }
                handleError(error)
                return
            }

            await waitForResultCollectionToFinish()
            guard recordingSessionID == sessionID else { return }

            guard !finalizedTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                await prepareForNextRecording()
                return
            }

            let transcriptForInsertion = await processTranscriptIfNeeded(
                finalizedTranscript,
                options: processingOptions,
                providerPreference: providerPreference
            )
            guard recordingSessionID == sessionID else { return }

            if settings.autoInsertText, !transcriptForInsertion.isEmpty {
                do {
                    await waitForHotkeyRelease()
                    guard recordingSessionID == sessionID else { return }

                    if let target = insertionTargetApplication,
                       target.bundleIdentifier != Bundle.main.bundleIdentifier,
                       !target.isTerminated {
                        NSApp.yieldActivation(to: target)
                        target.activate(options: [])
                        try await Task.sleep(for: .milliseconds(75))
                        guard recordingSessionID == sessionID else { return }
                    }

                    try await textInsertionService.insertText(
                        transcriptForInsertion,
                        autoInsert: settings.autoInsertText,
                        restoreClipboardAfterPaste: settings.restoreClipboardAfterPaste
                    )
                } catch {
                    guard recordingSessionID == sessionID else { return }
                    handleError(error)
                    return
                }
            }

            await prepareForNextRecording()
        }
    }

    private func waitForHotkeyRelease() async {
        let deadline = Date().addingTimeInterval(1)
        while hotkeyService.isHotkeyPressed, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(25))
        }
    }

    private func waitForResultCollectionToFinish() async {
        guard let resultCollectionTask else { return }

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await resultCollectionTask.value
            }
            group.addTask {
                try? await Task.sleep(for: .milliseconds(1500))
            }

            await group.next()
            group.cancelAll()
        }
    }

    func toggleRecording() async {
        if isRecording {
            stopRecording()
        } else {
            await startRecording()
        }
    }

    private func processTranscriptIfNeeded(
        _ text: String,
        options: TranscriptProcessingOptions,
        providerPreference: IntelligenceProviderPreference
    ) async -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return text
        }

        guard options.requiresModelProcessing else {
            return text
        }

        do {
            let processed = try await foundationModelsService.processTranscript(
                text,
                options: options,
                providerPreference: providerPreference
            )

            finalizedTranscript = processed
            return processed
        } catch {
            return text
        }
    }

    func resetTranscript() {
        volatileTranscript = ""
        finalizedTranscript = ""
    }

    func handleError(_ error: Error) {
        recordingState = .error(error)
        dismissOverlay()
        recordingTriggeredByHotkey = false
        resetRecordingResources()
    }

    func retrySetup() async {
        resetRecordingResources()
        permissionsService.refreshAll()

        guard hasRequiredPermissions else {
            recordingState = .requestingPermissions
            showOnboarding()
            return
        }

        startHotkeyMonitoringIfPossible()
        await setupSpeechEngine()
        if speechEngineService.isReady {
            recordingState = .ready
        }
    }

    private func prepareForNextRecording() async {
        resetRecordingResources()
        await setupSpeechEngine()
        if speechEngineService.isReady {
            recordingState = .ready
        }
    }

    private func resetRecordingResources() {
        recordingSessionID = UUID()
        recordingStartedAt = nil
        recordingTask?.cancel()
        recordingTask = nil
        resultCollectionTask?.cancel()
        resultCollectionTask = nil
        audioStream = nil
        insertionTargetApplication = nil
        hasCapturedAudio = false
        audioCaptureService.stop()
        speechEngineService.resetForNewSession()
    }

    private func showOverlay() {
        windowController.showRecordingOverlay(for: self)
    }

    private func dismissOverlay() {
        windowController.dismissRecordingOverlay()
    }

    func showOnboarding() {
        windowController.showOnboarding(for: self)
    }

    func dismissOnboarding() {
        windowController.dismissOnboarding()
    }

    func showSettings() {
        windowController.showSettings(for: self)
    }
}
