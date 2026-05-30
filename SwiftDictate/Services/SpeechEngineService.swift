import Speech
import AVFoundation
import Foundation

enum SpeechEngineError: Error, Equatable, LocalizedError {
    case transcriberNotInitialized
    case modelNotInstalled
    case modelDownloadFailed
    case analyzerStartFailed
    case inputStreamNotReady
    case localeNotSupported(Locale)
    case formatMismatch

    var errorDescription: String? {
        switch self {
        case .transcriberNotInitialized:
            "Speech transcriber has not been set up."
        case .modelNotInstalled:
            "Speech recognition model is not installed."
        case .modelDownloadFailed:
            "Failed to download the speech recognition model."
        case .analyzerStartFailed:
            "Failed to start speech analyzer."
        case .inputStreamNotReady:
            "Audio input stream is not ready."
        case .localeNotSupported(let locale):
            "The locale \"\(locale.identifier(.bcp47))\" is not supported for speech recognition."
        case .formatMismatch:
            "Audio format does not match speech analyzer requirements."
        }
    }
}

final class SpeechEngineService: @unchecked Sendable {
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var recognizerTask: Task<Void, Never>?
    private var analyzerFormat: AVAudioFormat?

    var isReady = false
    var isRunning = false
    var isSettingUp = false
    var downloadProgress: Progress?
    var modelState: ModelState = .unknown

    private var resultContinuation: AsyncStream<TranscriptionResult>.Continuation?
    private var _resultsStream: AsyncStream<TranscriptionResult>?

    enum ModelState: Equatable {
        case unknown
        case notRegistered
        case downloading
        case ready
        case failed(Error)

        static func == (lhs: ModelState, rhs: ModelState) -> Bool {
            switch (lhs, rhs) {
            case (.unknown, .unknown),
                 (.notRegistered, .notRegistered),
                 (.downloading, .downloading):
                return true
            case (.ready, .ready):
                return true
            case (.failed(let lhsError), .failed(let rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }
    }

    deinit {
        stopAnalysis()
    }

    func supportedLocale(for locale: Locale) async -> Bool {
        let supported = await SpeechTranscriber.supportedLocales
        return supported.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
    }

    func currentModelState(for locale: Locale) async {
        guard await supportedLocale(for: locale) else {
            modelState = .failed(SpeechEngineError.localeNotSupported(locale))
            return
        }

        let installed = await Set(SpeechTranscriber.installedLocales)
        let isInstalled = installed.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
        modelState = isInstalled ? .ready : .notRegistered
    }

    @MainActor
    func setupTranscriber(locale: Locale) async throws {
        guard !isReady, !isSettingUp else { return }

        isSettingUp = true
        defer { isSettingUp = false }

        let createdTranscriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        transcriber = createdTranscriber

        let createdAnalyzer = SpeechAnalyzer(modules: [createdTranscriber])
        analyzer = createdAnalyzer

        let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [createdTranscriber])
        guard let format else {
            throw SpeechEngineError.formatMismatch
        }
        analyzerFormat = format

        let (stream, builder) = AsyncStream<AnalyzerInput>.makeStream()
        inputBuilder = builder

        try await createdAnalyzer.start(inputSequence: stream)
        isReady = true
    }

    func downloadModelIfNeeded(for locale: Locale) async throws {
        guard await supportedLocale(for: locale) else {
            throw SpeechEngineError.localeNotSupported(locale)
        }

        let installed = await Set(SpeechTranscriber.installedLocales)
        let isInstalled = installed.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))

        if isInstalled {
            modelState = .ready
            return
        }

        let tempTranscriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)

        guard let downloader = try await AssetInventory.assetInstallationRequest(
            supporting: [tempTranscriber]
        ) else {
            modelState = .ready
            return
        }

        modelState = .downloading
        downloadProgress = downloader.progress

        do {
            try await downloader.downloadAndInstall()
            modelState = .ready
            downloadProgress = nil
        } catch {
            modelState = .failed(error)
            downloadProgress = nil
            throw SpeechEngineError.modelDownloadFailed
        }
    }

    var audioFormat: AVAudioFormat? {
        analyzerFormat
    }

    func startAnalysis() throws {
        guard isReady, let _ = inputBuilder else {
            throw SpeechEngineError.inputStreamNotReady
        }

        guard let transcriber else {
            throw SpeechEngineError.transcriberNotInitialized
        }

        isRunning = true

        recognizerTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                for try await result in transcriber.results {
                    guard !Task.isCancelled else { break }

                    let transcriptionResult = TranscriptionResult(
                        text: String(result.text.characters),
                        attributedText: result.text,
                        isFinal: result.isFinal,
                        audioTimeRange: nil
                    )

                    self.resultContinuation?.yield(transcriptionResult)
                }
            } catch {
                if !(error is CancellationError) {
                    self.resultContinuation?.yield(
                        TranscriptionResult(
                            text: "",
                            attributedText: AttributedString(),
                            isFinal: true,
                            audioTimeRange: nil
                        )
                    )
                }
            }
        }
    }

    func feedAudioBuffer(_ buffer: AVAudioPCMBuffer) throws {
        guard let inputBuilder, let analyzerFormat else {
            throw SpeechEngineError.inputStreamNotReady
        }

        let sourceFormat = buffer.format

        let converted: AVAudioPCMBuffer
        if sourceFormat.commonFormat == analyzerFormat.commonFormat,
           sourceFormat.sampleRate == analyzerFormat.sampleRate,
           sourceFormat.channelCount == analyzerFormat.channelCount {
            converted = buffer
        } else {
            guard let converter = AVAudioConverter(from: sourceFormat, to: analyzerFormat),
                  let outputBuffer = AVAudioPCMBuffer(
                    pcmFormat: analyzerFormat,
                    frameCapacity: AVAudioFrameCount(
                        Double(buffer.frameLength) * analyzerFormat.sampleRate / sourceFormat.sampleRate
                    )
                  ) else {
                throw SpeechEngineError.formatMismatch
            }

            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
            if status == .error || error != nil {
                throw SpeechEngineError.formatMismatch
            }

            converted = outputBuffer
        }

        let input = AnalyzerInput(buffer: converted)
        inputBuilder.yield(input)
    }

    func finalizeResults() async throws {
        guard let analyzer else {
            throw SpeechEngineError.analyzerStartFailed
        }

        try await analyzer.finalizeAndFinishThroughEndOfInput()
    }

    func stopAnalysis() {
        isRunning = false
        recognizerTask?.cancel()
        recognizerTask = nil
    }

    func finishInput() {
        inputBuilder?.finish()
    }

    func resetForNewSession() {
        stopAnalysis()
        inputBuilder?.finish()
        inputBuilder = nil
        resultContinuation?.finish()
        resultContinuation = nil
        _resultsStream = nil
        recognizerTask = nil
        isRunning = false
        isReady = false
        transcriber = nil
        analyzer = nil
        analyzerFormat = nil
    }

    func results() -> AsyncStream<TranscriptionResult> {
        if let existing = _resultsStream {
            return existing
        }
        let stream = AsyncStream<TranscriptionResult> { continuation in
            self.resultContinuation = continuation
        }
        _resultsStream = stream
        return stream
    }

    func cancel() {
        inputBuilder?.finish()
        inputBuilder = nil
        resultContinuation?.finish()
        resultContinuation = nil
        recognizerTask?.cancel()
        recognizerTask = nil
        isRunning = false
        isReady = false
        transcriber = nil
        analyzer = nil
        analyzerFormat = nil
    }
}
