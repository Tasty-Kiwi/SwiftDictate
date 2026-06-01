import SwiftUI
import AVFoundation
import Observation

private final class RecordingOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

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
    var overlayWindow: NSWindow?
    var recordingTriggeredByHotkey = false

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
    private var onboardingShown = false
    private var insertionTargetApplication: NSRunningApplication?

    init() {
        Task { @MainActor in
            await initialize()
            hotkeyService.start()

            if !hotkeyService.globalMonitorActive {
                print("[SwiftDictate] Global monitor not active — re-requesting accessibility to refresh TCC entry")
                permissionsService.requestAccessibility()
                await permissionsService.pollAccessibilityUntilTrusted()
                hotkeyService.stop()
                hotkeyService.start()
            }

            if !hasRequiredPermissions, !onboardingShown {
                onboardingShown = true
                showOnboarding()
            }
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
        permissionsService.microphoneAuthorized && permissionsService.accessibilityTrusted
    }

    func initialize() async {
        permissionsService.refreshAll()

        if !permissionsService.accessibilityTrusted {
            permissionsService.requestAccessibility()
            await permissionsService.pollAccessibilityUntilTrusted()
        }

        foundationModelsService.checkAvailability()

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.permissionsService.refreshAll()

                if self.permissionsService.accessibilityTrusted, !self.hotkeyService.globalMonitorActive {
                    self.hotkeyService.stop()
                    self.hotkeyService.start()
                }

                if self.hasRequiredPermissions,
                   self.recordingState == .requestingPermissions {
                    self.recordingState = .ready
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

                if self.permissionsService.accessibilityTrusted, !self.hotkeyService.globalMonitorActive {
                    self.hotkeyService.stop()
                    self.hotkeyService.start()
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
        recordingTriggeredByHotkey = true
        print("[SwiftDictate] handleHotkeyPress — mode: \(settings.recordingMode.displayName)")

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
        print("[SwiftDictate] handleHotkeyRelease — isRecording: \(isRecording)")
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
        insertionTargetApplication = NSWorkspace.shared.frontmostApplication

        if recordingTriggeredByHotkey {
            showOverlay()
        }

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
        dismissOverlay()
        recordingTriggeredByHotkey = false

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
                return
            }

            await waitForResultCollectionToFinish()

            guard !finalizedTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                print("[SwiftDictate] Skipping processing/insertion because transcription returned empty text")
                speechEngineService.resetForNewSession()
                resultCollectionTask = nil
                insertionTargetApplication = nil
                await setupSpeechEngine()
                recordingState = speechEngineService.isReady ? .ready : .error(SpeechEngineError.transcriberNotInitialized)
                return
            }

            let transcriptForInsertion = await processTranscriptIfNeeded(finalizedTranscript)

            if settings.autoInsertText, !transcriptForInsertion.isEmpty {
                do {
                    await waitForHotkeyRelease()

                    if let target = insertionTargetApplication,
                       target.bundleIdentifier != Bundle.main.bundleIdentifier,
                       !target.isTerminated {
                        NSApp.yieldActivation(to: target)
                        target.activate(options: [])
                        try await Task.sleep(for: .milliseconds(75))
                    }

                    try await textInsertionService.insertText(
                        transcriptForInsertion,
                        autoInsert: settings.autoInsertText,
                        clearClipboardAfterPaste: settings.clearClipboardAfterPaste
                    )
                } catch {
                    handleError(error)
                    return
                }
            }

            speechEngineService.resetForNewSession()
            resultCollectionTask?.cancel()
            resultCollectionTask = nil
            insertionTargetApplication = nil

            await setupSpeechEngine()

            recordingState = speechEngineService.isReady ? .ready : .error(SpeechEngineError.transcriberNotInitialized)
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

    func processTranscript(_ text: String) {
        Task {
            _ = await processTranscriptIfNeeded(text)
        }
    }

    private func processTranscriptIfNeeded(_ text: String) async -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("[SwiftDictate] FM processing skipped — empty transcript")
            return text
        }

        guard settings.enableFoundationModels, foundationModelsService.isAvailable else {
            print("[SwiftDictate] FM processing skipped — enabled:\(settings.enableFoundationModels) available:\(foundationModelsService.isAvailable)")
            return text
        }

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
            return processed
        } catch {
            print("[SwiftDictate] FM processing failed: \(error.localizedDescription)")
            return text
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
        dismissOverlay()
        recordingTriggeredByHotkey = false

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

    private func showOverlay() {
        guard overlayWindow == nil else { return }

        let overlay = RecordingOverlayView().environment(self)
        let hostingVC = NSHostingController(rootView: overlay)
        let window = RecordingOverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingVC
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.center()
        window.orderFrontRegardless()
        overlayWindow = window
    }

    private func dismissOverlay() {
        overlayWindow?.close()
        overlayWindow = nil
    }

    func cleanup() {
        stopRecording()
        hotkeyService.stop()
        speechEngineService.cancel()
        foundationModelsService.resetSession()
    }

    func showOnboarding() {
        guard onboardingWindow == nil else { return }

        let onboardingVC = NSHostingController(
            rootView: PermissionsOnboardingView()
                .environment(self)
                .onChange(of: hasRequiredPermissions) { _, hasPermissions in
                    if hasPermissions {
                        self.onboardingWindow?.close()
                        self.onboardingWindow = nil
                    }
                }
        )

        let window = NSWindow(contentViewController: onboardingVC)
        window.title = "Welcome to SwiftDictate"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 440, height: 520))
        window.center()
        window.makeKeyAndOrderFront(nil)
        onboardingWindow = window
    }
}
